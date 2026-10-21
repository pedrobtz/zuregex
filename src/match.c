// Phase 1 subject collection, and re_detect() / re_count().

#include <limits.h>
#include <string.h>

#include "zuregex.h"
#include "match.h"
#include "omp.h"

static void set_subject(zuregex_subject *s, const char *ptr, size_t len) {
  // Offsets are returned as R integers.
  if (len > (size_t) INT_MAX) {
    Rf_error("subjects longer than %d bytes are not supported", INT_MAX);
  }
  // R gives a zero-length vector a dummy data pointer (0x1), and PCRE2
  // computes with the subject pointer even for an empty subject; UBSan
  // reports that arithmetic. An empty subject points at a real "".
  s->ptr = len > 0 ? ptr : "";
  s->len = len;
  s->na = 0;
}

// x is a character vector, a raw vector (one subject) or a list of raw
// vectors and NULLs. In UTF-8 mode, strings in other declared encodings are
// translated here, on the main thread; R_alloc() memory lives until .Call
// returns. In bytes mode, strings are matched as the bytes they hold.
// PCRE2's contexts allocate through R_alloc(), so a context made for a
// call is released when .Call returns, even if an R error ends it early.
static void *r_alloc_for_pcre2(size_t size, void *data) {
  (void) data;
  return R_alloc(size, 1);
}

static void no_free(void *ptr, void *data) {
  (void) ptr;
  (void) data;
}

static void set_limits(SEXP limits, zuregex_call *call) {
  call->mctx = NULL;
  call->limit_na = 0;
  if (XLENGTH(limits) != 4) Rf_error("internal error: limits must have length 4");
  const double *l = REAL(limits);
  call->limit_na = !ISNAN(l[3]) && l[3] != 0;
  if (ISNAN(l[0]) && ISNAN(l[1]) && ISNAN(l[2])) return;
  pcre2_general_context *gctx =
    pcre2_general_context_create(r_alloc_for_pcre2, no_free, NULL);
  call->mctx = pcre2_match_context_create(gctx);
  if (call->mctx == NULL) Rf_error("out of memory creating a match context");
  if (!ISNAN(l[0])) pcre2_set_match_limit(call->mctx, (uint32_t) l[0]);
  if (!ISNAN(l[1])) pcre2_set_depth_limit(call->mctx, (uint32_t) l[1]);
  if (!ISNAN(l[2])) pcre2_set_heap_limit(call->mctx, (uint32_t) l[2]);
}

void zuregex_collect(SEXP x, int bytes, SEXP table, SEXP index, SEXP limits,
                     zuregex_call *call) {
  set_limits(limits, call);
  if (TYPEOF(x) == RAWSXP) {
    call->n = 1;
  } else {
    call->n = XLENGTH(x);
  }
  // Element numbers are returned as R integers too.
  if (call->n > INT_MAX) {
    Rf_error("inputs longer than %d elements are not supported", INT_MAX);
  }
  call->subjects = (zuregex_subject *) R_alloc(
    call->n > 0 ? (size_t) call->n : 1, sizeof(zuregex_subject));

  if (TYPEOF(x) == RAWSXP) {
    set_subject(&call->subjects[0], (const char *) RAW(x), (size_t) XLENGTH(x));
  } else if (TYPEOF(x) == VECSXP) {
    for (R_xlen_t i = 0; i < call->n; i++) {
      SEXP el = VECTOR_ELT(x, i);
      if (TYPEOF(el) == RAWSXP) {
        set_subject(&call->subjects[i], (const char *) RAW(el),
                    (size_t) XLENGTH(el));
      } else {
        call->subjects[i].na = 1;
      }
    }
  } else {
    for (R_xlen_t i = 0; i < call->n; i++) {
      SEXP s = STRING_ELT(x, i);
      if (s == NA_STRING) {
        call->subjects[i].na = 1;
      } else if (bytes || Rf_charIsASCII(s) || Rf_charIsUTF8(s)) {
        set_subject(&call->subjects[i], CHAR(s), (size_t) LENGTH(s));
      } else {
        const char *t = Rf_translateCharUTF8(s);
        set_subject(&call->subjects[i], t, strlen(t));
      }
    }
  }

  call->n_patterns = (int) XLENGTH(table);
  call->patterns = (zuregex_pattern **) R_alloc(
    call->n_patterns > 0 ? (size_t) call->n_patterns : 1,
    sizeof(zuregex_pattern *));
  call->max_ovector = 1;
  for (int k = 0; k < call->n_patterns; k++) {
    SEXP ptr = VECTOR_ELT(table, k);
    zuregex_pattern *p =
      TYPEOF(ptr) == EXTPTRSXP ? R_ExternalPtrAddr(ptr) : NULL;
    if (p == NULL) Rf_error("internal error: pattern %d is not compiled", k + 1);
    call->patterns[k] = p;
    uint32_t groups = 0;
    pcre2_pattern_info(p->code, PCRE2_INFO_CAPTURECOUNT, &groups);
    if (groups + 1 > call->max_ovector) call->max_ovector = groups + 1;
  }
  call->index = INTEGER(index);
  call->index_len = (int) XLENGTH(index);
  call->total_bytes = 0;
  for (R_xlen_t i = 0; i < call->n; i++) {
    if (!call->subjects[i].na) call->total_bytes += (double) call->subjects[i].len;
  }
}

zuregex_pattern *zuregex_pattern_for(const zuregex_call *call, R_xlen_t i) {
  if (call->subjects[i].na) return NULL;
  int k = call->index[call->index_len == 1 ? 0 : i];
  if (k == NA_INTEGER) return NULL;
  return call->patterns[k - 1];
}

static int is_utf_error(int rc) {
  return rc <= PCRE2_ERROR_UTF8_ERR1 && rc >= PCRE2_ERROR_UTF8_ERR21;
}

int zuregex_is_limit(int rc) {
  return rc == PCRE2_ERROR_MATCHLIMIT || rc == PCRE2_ERROR_DEPTHLIMIT ||
         rc == PCRE2_ERROR_HEAPLIMIT || rc == PCRE2_ERROR_JIT_STACKLIMIT;
}

double zuregex_limited(const zuregex_call *call, const zuregex_status *status) {
  double n = 0;
  if (!call->limit_na) return 0;
  for (R_xlen_t i = 0; i < call->n; i++) {
    if (!status[i].in_template && zuregex_is_limit(status[i].rc)) n++;
  }
  return n;
}

SEXP zuregex_status_error(const zuregex_call *call,
                          const zuregex_status *status) {
  for (R_xlen_t i = 0; i < call->n; i++) {
    if (status[i].rc == 0) continue;
    int limit = !status[i].in_template && zuregex_is_limit(status[i].rc);
    if (limit && call->limit_na) continue;
    PCRE2_UCHAR msg[256];
    if (pcre2_get_error_message(status[i].rc, msg, sizeof(msg)) < 0) {
      strcpy((char *) msg, "unknown error");
    }
    const char *names[] = {"kind", "element", "rc", "offset", "message", ""};
    SEXP err = PROTECT(Rf_mkNamed(VECSXP, names));
    const char *kind = status[i].in_template ? "template"
                       : limit                         ? "limit"
                       : is_utf_error(status[i].rc)    ? "utf"
                       : "match";
    SET_VECTOR_ELT(err, 0, Rf_mkString(kind));
    SET_VECTOR_ELT(err, 1, Rf_ScalarReal((double) i + 1));
    SET_VECTOR_ELT(err, 2, Rf_ScalarInteger(status[i].rc));
    SET_VECTOR_ELT(err, 3, Rf_ScalarReal((double) status[i].offset + 1));
    SET_VECTOR_ELT(err, 4, Rf_mkString((const char *) msg));
    UNPROTECT(1);
    return err;
  }
  return R_NilValue;
}

int zuregex_match_once(const zuregex_call *call, const zuregex_pattern *p,
                       const zuregex_subject *s, size_t start,
                       uint32_t options, pcre2_match_data *md,
                       zuregex_status *st) {
  int rc = pcre2_match(p->code, (PCRE2_SPTR) s->ptr, s->len, start, options,
                       md, call->mctx);
  if (rc >= 0) return 1;
  if (rc == PCRE2_ERROR_NOMATCH) return 0;
  st->rc = rc;
  // After a UTF error, pcre2_get_startchar() is the byte offset of the
  // invalid character.
  st->offset = is_utf_error(rc) ? pcre2_get_startchar(md) : 0;
  return -1;
}

// The byte offset one character after `at`.
static size_t step_char(const zuregex_subject *s, size_t at, int utf) {
  if (at >= s->len) return s->len + 1;
  at++;
  if (utf) {
    while (at < s->len && ((unsigned char) s->ptr[at] & 0xC0) == 0x80) at++;
  }
  return at;
}

int zuregex_next_start(const zuregex_pattern *p, const zuregex_subject *s,
                       pcre2_match_data *md, int overlap, size_t *start,
                       uint32_t *options) {
  PCRE2_SIZE *ov = pcre2_get_ovector_pointer(md);
  int utf = p->key.utf;
  if (overlap) {
    size_t next = step_char(s, ov[0], utf);
    if (next > s->len) return 0;
    *start = next;
    *options = PCRE2_NO_UTF_CHECK * (uint32_t) utf;
    return 1;
  }
  if (p->key.dialect == ZUREGEX_DIALECT_JS) {
    // ECMA-262 RegExp.prototype[@@match]: lastIndex is the match end, and
    // after an empty match it advances by one character.
    size_t next = ov[1];
    if (ov[1] <= ov[0]) next = step_char(s, ov[1], utf);
    if (next > s->len) return 0;
    *start = next;
    *options = PCRE2_NO_UTF_CHECK * (uint32_t) utf;
    return 1;
  }
  PCRE2_SIZE next = 0;
  uint32_t opts = 0;
  if (!pcre2_next_match(md, &next, &opts)) return 0;
  *start = next;
  // After the first search the subject has been checked as UTF-8.
  *options = opts | (PCRE2_NO_UTF_CHECK * (uint32_t) utf);
  return 1;
}

size_t zuregex_chars(const char *s, size_t bytes, int utf) {
  if (!utf) return bytes;
  size_t chars = 0;
  for (size_t i = 0; i < bytes; i++) {
    if (((unsigned char) s[i] & 0xC0) != 0x80) chars++;
  }
  return chars;
}

static uint32_t anchor_options(int anchor) {
  switch (anchor) {
  case 1: return PCRE2_ANCHORED;
  case 2: return PCRE2_ANCHORED | PCRE2_ENDANCHORED;
  default: return 0;
  }
}

SEXP zuregex_result(const zuregex_call *call, const zuregex_status *status,
                    SEXP value, SEXP error) {
  const char *names[] = {"value", "error", "limited", ""};
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(out, 0, value);
  SET_VECTOR_ELT(out, 1, error);
  SET_VECTOR_ELT(out, 2, Rf_ScalarReal(zuregex_limited(call, status)));
  UNPROTECT(1);
  return out;
}

// anchor: 0 none, 1 start, 2 full.
SEXP zuregex_detect_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                      SEXP anchor, SEXP negate) {
  zuregex_call call;
  zuregex_collect(x, Rf_asLogical(bytes), table, index, limits, &call);
  uint32_t options = anchor_options(Rf_asInteger(anchor));
  int neg = Rf_asLogical(negate);

  SEXP out = PROTECT(Rf_allocVector(LGLSXP, call.n));
  int *res = LOGICAL(out);
  zuregex_status *status = (zuregex_status *) R_alloc(
    call.n > 0 ? (size_t) call.n : 1, sizeof(zuregex_status));
  memset(status, 0, (call.n > 0 ? (size_t) call.n : 1) * sizeof(zuregex_status));
  // Phase 2: no R API, and on several threads.
  int nt = zuregex_threads_for(&call);
  ZUREGEX_OMP_PARALLEL
  {
    pcre2_match_data *md = pcre2_match_data_create(call.max_ovector, NULL);
    ZUREGEX_OMP_FOR
    for (R_xlen_t i = 0; i < call.n; i++) {
      const zuregex_pattern *p = zuregex_pattern_for(&call, i);
      res[i] = NA_LOGICAL;
      if (p == NULL) continue;
      if (md == NULL) {
        status[i].rc = PCRE2_ERROR_NOMEMORY;
        continue;
      }
      int m = zuregex_match_once(&call, p, &call.subjects[i], 0, options, md,
                                 &status[i]);
      if (m >= 0) res[i] = neg ? !m : m;
    }
    pcre2_match_data_free(md);
  }

  // Phase 3.
  SEXP err = PROTECT(zuregex_status_error(&call, status));
  SEXP ans = zuregex_result(&call, status, Rf_isNull(err) ? out : R_NilValue, err);
  UNPROTECT(2);
  return ans;
}

SEXP zuregex_count_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits) {
  zuregex_call call;
  zuregex_collect(x, Rf_asLogical(bytes), table, index, limits, &call);

  SEXP out = PROTECT(Rf_allocVector(INTSXP, call.n));
  int *res = INTEGER(out);
  zuregex_status *status = (zuregex_status *) R_alloc(
    call.n > 0 ? (size_t) call.n : 1, sizeof(zuregex_status));
  memset(status, 0, (call.n > 0 ? (size_t) call.n : 1) * sizeof(zuregex_status));
  // Phase 2. Successive matches follow the pattern's dialect
  // (zuregex_next_start()).
  int nt = zuregex_threads_for(&call);
  ZUREGEX_OMP_PARALLEL
  {
    pcre2_match_data *md = pcre2_match_data_create(call.max_ovector, NULL);
    ZUREGEX_OMP_FOR
    for (R_xlen_t i = 0; i < call.n; i++) {
      const zuregex_pattern *p = zuregex_pattern_for(&call, i);
      res[i] = NA_INTEGER;
      if (p == NULL) continue;
      if (md == NULL) {
        status[i].rc = PCRE2_ERROR_NOMEMORY;
        continue;
      }
      const zuregex_subject *s = &call.subjects[i];
      size_t start = 0;
      uint32_t options = 0;
      int count = 0;
      for (;;) {
        int m = zuregex_match_once(&call, p, s, start, options, md, &status[i]);
        if (m < 0) {
          count = NA_INTEGER;
          break;
        }
        if (m == 0) break;
        count++;
        if (!zuregex_next_start(p, s, md, 0, &start, &options)) break;
      }
      res[i] = count;
    }
    pcre2_match_data_free(md);
  }

  SEXP err = PROTECT(zuregex_status_error(&call, status));
  SEXP ans = zuregex_result(&call, status, Rf_isNull(err) ? out : R_NilValue, err);
  UNPROTECT(2);
  return ans;
}

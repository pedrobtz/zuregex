// Phase 1 subject collection, and re_detect() / re_count().

#include <string.h>

#include "zuregex.h"
#include "match.h"

static void set_subject(zuregex_subject *s, const char *ptr, size_t len) {
  s->ptr = ptr;
  s->len = len;
  s->na = 0;
}

// x is a character vector, a raw vector (one subject) or a list of raw
// vectors and NULLs. In UTF-8 mode, strings in other declared encodings are
// translated here, on the main thread; R_alloc() memory lives until .Call
// returns. In bytes mode, strings are matched as the bytes they hold.
void zuregex_collect(SEXP x, int bytes, SEXP table, SEXP index,
                     zuregex_call *call) {
  if (TYPEOF(x) == RAWSXP) {
    call->n = 1;
  } else {
    call->n = XLENGTH(x);
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

SEXP zuregex_status_error(const zuregex_call *call,
                          const zuregex_status *status) {
  for (R_xlen_t i = 0; i < call->n; i++) {
    if (status[i].rc == 0) continue;
    PCRE2_UCHAR msg[256];
    if (pcre2_get_error_message(status[i].rc, msg, sizeof(msg)) < 0) {
      strcpy((char *) msg, "unknown error");
    }
    const char *names[] = {"kind", "element", "rc", "offset", "message", ""};
    SEXP err = PROTECT(Rf_mkNamed(VECSXP, names));
    SET_VECTOR_ELT(err, 0, Rf_mkString(is_utf_error(status[i].rc) ? "utf" : "match"));
    SET_VECTOR_ELT(err, 1, Rf_ScalarReal((double) i + 1));
    SET_VECTOR_ELT(err, 2, Rf_ScalarInteger(status[i].rc));
    SET_VECTOR_ELT(err, 3, Rf_ScalarReal((double) status[i].offset + 1));
    SET_VECTOR_ELT(err, 4, Rf_mkString((const char *) msg));
    UNPROTECT(1);
    return err;
  }
  return R_NilValue;
}

// One pcre2_match(). Returns 1 for a match, 0 for none, and records any
// other outcome in *st.
static int match_once(const zuregex_pattern *p, const zuregex_subject *s,
                      size_t start, uint32_t options, pcre2_match_data *md,
                      zuregex_status *st) {
  int rc = pcre2_match(p->code, (PCRE2_SPTR) s->ptr, s->len, start, options,
                       md, NULL);
  if (rc >= 0) return 1;
  if (rc == PCRE2_ERROR_NOMATCH) return 0;
  st->rc = rc;
  // After a UTF error, pcre2_get_startchar() is the byte offset of the
  // invalid character.
  st->offset = is_utf_error(rc) ? pcre2_get_startchar(md) : 0;
  return -1;
}

static uint32_t anchor_options(int anchor) {
  switch (anchor) {
  case 1: return PCRE2_ANCHORED;
  case 2: return PCRE2_ANCHORED | PCRE2_ENDANCHORED;
  default: return 0;
  }
}

static SEXP result(SEXP value, SEXP error) {
  const char *names[] = {"value", "error", ""};
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(out, 0, value);
  SET_VECTOR_ELT(out, 1, error);
  UNPROTECT(1);
  return out;
}

// anchor: 0 none, 1 start, 2 full.
SEXP zuregex_detect_c(SEXP x, SEXP bytes, SEXP table, SEXP index,
                      SEXP anchor, SEXP negate) {
  zuregex_call call;
  zuregex_collect(x, Rf_asLogical(bytes), table, index, &call);
  uint32_t options = anchor_options(Rf_asInteger(anchor));
  int neg = Rf_asLogical(negate);

  SEXP out = PROTECT(Rf_allocVector(LGLSXP, call.n));
  int *res = LOGICAL(out);
  zuregex_status *status = (zuregex_status *) R_alloc(
    call.n > 0 ? (size_t) call.n : 1, sizeof(zuregex_status));
  memset(status, 0, (call.n > 0 ? (size_t) call.n : 1) * sizeof(zuregex_status));
  pcre2_match_data *md = pcre2_match_data_create(call.max_ovector, NULL);
  if (md == NULL) Rf_error("out of memory allocating match data");

  // Phase 2: no R API from here to the end of the loop.
  for (R_xlen_t i = 0; i < call.n; i++) {
    const zuregex_pattern *p = zuregex_pattern_for(&call, i);
    if (p == NULL) {
      res[i] = NA_LOGICAL;
      continue;
    }
    int m = match_once(p, &call.subjects[i], 0, options, md, &status[i]);
    res[i] = m < 0 ? NA_LOGICAL : (neg ? !m : m);
  }
  pcre2_match_data_free(md);

  // Phase 3.
  SEXP err = PROTECT(zuregex_status_error(&call, status));
  SEXP ans = result(Rf_isNull(err) ? out : R_NilValue, err);
  UNPROTECT(2);
  return ans;
}

SEXP zuregex_count_c(SEXP x, SEXP bytes, SEXP table, SEXP index) {
  zuregex_call call;
  zuregex_collect(x, Rf_asLogical(bytes), table, index, &call);

  SEXP out = PROTECT(Rf_allocVector(INTSXP, call.n));
  int *res = INTEGER(out);
  zuregex_status *status = (zuregex_status *) R_alloc(
    call.n > 0 ? (size_t) call.n : 1, sizeof(zuregex_status));
  memset(status, 0, (call.n > 0 ? (size_t) call.n : 1) * sizeof(zuregex_status));
  pcre2_match_data *md = pcre2_match_data_create(call.max_ovector, NULL);
  if (md == NULL) Rf_error("out of memory allocating match data");

  // Phase 2. Successive matches follow PCRE2's own rule for where the next
  // search starts after an empty match (pcre2_next_match()).
  for (R_xlen_t i = 0; i < call.n; i++) {
    const zuregex_pattern *p = zuregex_pattern_for(&call, i);
    if (p == NULL) {
      res[i] = NA_INTEGER;
      continue;
    }
    PCRE2_SIZE start = 0;
    uint32_t options = 0;
    int count = 0;
    for (;;) {
      int m = match_once(p, &call.subjects[i], start, options, md, &status[i]);
      if (m < 0) {
        count = NA_INTEGER;
        break;
      }
      if (m == 0) break;
      count++;
      if (!pcre2_next_match(md, &start, &options)) break;
      // After the first search the subject has been checked as UTF-8.
      options |= PCRE2_NO_UTF_CHECK;
    }
    res[i] = count;
  }
  pcre2_match_data_free(md);

  SEXP err = PROTECT(zuregex_status_error(&call, status));
  SEXP ans = result(Rf_isNull(err) ? out : R_NilValue, err);
  UNPROTECT(2);
  return ans;
}

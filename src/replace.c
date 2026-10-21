// re_replace() and re_expand().
//
// Matches are found with the same iteration as every other verb
// (zuregex_next_start()). Each match's replacement text comes either from
// pcre2_substitute() with PCRE2_SUBSTITUTE_MATCHED and
// PCRE2_SUBSTITUTE_REPLACEMENT_ONLY, which expands the template against the
// match just found without searching again, or, for a replacement function,
// from the strings it returned. The output is assembled in phase 2 in
// malloc()ed buffers and turned into R strings in phase 3.

#include <stdlib.h>
#include <string.h>

#include "zuregex.h"
#include "match.h"

typedef struct {
  char *buf;
  size_t len, cap;
  int state;  // 0 unchanged (no match), 1 built, -1 NA
} out_buf;

typedef struct {
  zuregex_call *call;
  out_buf *out;
  SEXP x;     // to return unmatched elements unchanged
  int expand;
} replace_job;

// Room for n more bytes after o->len.
static int reserve(out_buf *o, size_t n) {
  if (o->len + n + 1 <= o->cap) return 1;
  size_t cap = o->cap ? o->cap : 64;
  while (o->len + n + 1 > cap) cap *= 2;
  char *grown = realloc(o->buf, cap);
  if (grown == NULL) return 0;
  o->buf = grown;
  o->cap = cap;
  return 1;
}

static int append(out_buf *o, const char *s, size_t n) {
  if (!reserve(o, n)) return 0;
  if (n > 0) memcpy(o->buf + o->len, s, n);
  o->len += n;
  return 1;
}

static void free_out(void *data) {
  replace_job *job = data;
  if (job->out == NULL) return;
  for (R_xlen_t i = 0; i < job->call->n; i++) free(job->out[i].buf);
  free(job->out);
  job->out = NULL;
}

// Expands `tmpl` against the match in `md`, found at `start` with
// `options`, appending the text to `o`. Returns 1, 0 for out of memory, or
// -1 with the error in *st.
static int expand(const zuregex_pattern *p, const zuregex_subject *s,
                  size_t start, uint32_t options, pcre2_match_data *md,
                  const zuregex_subject *tmpl, uint32_t syntax, out_buf *o,
                  zuregex_status *st) {
  uint32_t sub = options | syntax | PCRE2_SUBSTITUTE_MATCHED |
                 PCRE2_SUBSTITUTE_REPLACEMENT_ONLY |
                 PCRE2_SUBSTITUTE_UNSET_EMPTY | PCRE2_SUBSTITUTE_OVERFLOW_LENGTH;
  // Room for the template's own length is usually enough; if not, PCRE2
  // says how much it needs (PCRE2_SUBSTITUTE_OVERFLOW_LENGTH) and the call
  // is repeated once with that much.
  PCRE2_SIZE need = tmpl->len + 64;
  for (int attempt = 0; attempt < 2; attempt++) {
    if (!reserve(o, need)) return 0;
    PCRE2_SIZE outlen = need + 1;
    int rc = pcre2_substitute(p->code, (PCRE2_SPTR) s->ptr, s->len, start,
                              sub, md, NULL, (PCRE2_SPTR) tmpl->ptr,
                              tmpl->len, (PCRE2_UCHAR *) o->buf + o->len,
                              &outlen);
    if (rc >= 0) {
      o->len += outlen;
      return 1;
    }
    if (rc == PCRE2_ERROR_NOMEMORY && attempt == 0) {
      need = outlen;
      continue;
    }
    st->rc = rc;
    st->in_template = 1;
    // For an error in the template, outlen is where in it PCRE2 stopped.
    st->offset = outlen == PCRE2_UNSET ? 0 : outlen;
    return -1;
  }
  return 0;
}

static SEXP build(void *data) {
  replace_job *job = data;
  zuregex_call *call = job->call;
  SEXP res = PROTECT(Rf_allocVector(STRSXP, call->n));
  for (R_xlen_t i = 0; i < call->n; i++) {
    out_buf *o = &job->out[i];
    if (o->state < 0 || (job->expand && o->state == 0)) {
      SET_STRING_ELT(res, i, NA_STRING);
    } else if (o->state == 0) {
      // No match: the element as it was, in its own encoding. Only a
      // character vector reaches here; raw input is always rebuilt.
      if (TYPEOF(job->x) == STRSXP) {
        SET_STRING_ELT(res, i, STRING_ELT(job->x, i));
      } else {
        const zuregex_subject *s = &call->subjects[i];
        SET_STRING_ELT(res, i, Rf_mkCharLenCE(s->ptr, (int) s->len, CE_BYTES));
      }
    } else {
      const zuregex_pattern *p = zuregex_pattern_for(call, i);
      int utf = p != NULL ? p->key.utf : 1;
      SET_STRING_ELT(res, i, Rf_mkCharLenCE(o->buf, (int) o->len,
                                            utf ? CE_UTF8 : CE_BYTES));
    }
  }
  UNPROTECT(1);
  return res;
}

// mode 0: `repl` holds templates, one or one per element, expanded with
// `syntax`. mode 1: `repl` holds one string per match, in order, from a
// replacement function. expand: return only the first match's expansion.
SEXP zuregex_replace_c(SEXP x, SEXP bytes, SEXP table, SEXP index,
                       SEXP repl, SEXP mode, SEXP literal, SEXP n_max,
                       SEXP expand_only) {
  zuregex_call call;
  int is_bytes = Rf_asLogical(bytes);
  zuregex_collect(x, is_bytes, table, index, &call);
  int per_match = Rf_asInteger(mode) == 1;
  uint32_t syntax = Rf_asLogical(literal) ? PCRE2_SUBSTITUTE_LITERAL
                                          : PCRE2_SUBSTITUTE_EXTENDED;
  double limit = Rf_asReal(n_max);
  int expand_flag = Rf_asLogical(expand_only);
  if (expand_flag) limit = 1;

  // Phase 1: the replacement strings as UTF-8 (or bytes) pointers.
  R_xlen_t nr = XLENGTH(repl);
  zuregex_subject *r = (zuregex_subject *) R_alloc(nr > 0 ? (size_t) nr : 1,
                                                   sizeof(zuregex_subject));
  for (R_xlen_t j = 0; j < nr; j++) {
    SEXP s = STRING_ELT(repl, j);
    r[j].na = s == NA_STRING;
    if (r[j].na) continue;
    if (is_bytes || Rf_charIsASCII(s) || Rf_charIsUTF8(s)) {
      r[j].ptr = CHAR(s);
      r[j].len = (size_t) LENGTH(s);
    } else {
      r[j].ptr = Rf_translateCharUTF8(s);
      r[j].len = strlen(r[j].ptr);
    }
  }

  size_t n = call.n > 0 ? (size_t) call.n : 1;
  zuregex_status *status = (zuregex_status *) R_alloc(n, sizeof(zuregex_status));
  memset(status, 0, n * sizeof(zuregex_status));
  replace_job job = {&call, NULL, x, expand_flag};
  job.out = calloc(n, sizeof(out_buf));
  pcre2_match_data *md = pcre2_match_data_create(call.max_ovector, NULL);
  if (job.out == NULL || md == NULL) {
    free(job.out);
    pcre2_match_data_free(md);
    Rf_error("out of memory allocating replacement buffers");
  }

  // Phase 2: no R API.
  int oom = 0;
  R_xlen_t next_repl = 0;  // per-match strings are consumed in order
  for (R_xlen_t i = 0; i < call.n && !oom; i++) {
    const zuregex_pattern *p = zuregex_pattern_for(&call, i);
    out_buf *o = &job.out[i];
    const zuregex_subject *tmpl = per_match ? NULL : &r[nr == 1 ? 0 : i];
    if (p == NULL || (tmpl != NULL && tmpl->na)) {
      o->state = -1;
      continue;
    }
    const zuregex_subject *s = &call.subjects[i];
    size_t start = 0, last = 0;
    uint32_t options = 0;
    int matches = 0;
    while (matches < limit) {
      int m = zuregex_match_once(p, s, start, options, md, &status[i]);
      if (m < 0) {
        o->state = -1;
        break;
      }
      if (m == 0) break;
      PCRE2_SIZE *ov = pcre2_get_ovector_pointer(md);
      size_t m0 = ov[0], m1 = ov[1];
      matches++;
      o->state = 1;
      if (!expand_flag && m0 >= last &&
          !append(o, s->ptr + last, m0 - last)) {
        oom = 1;
        break;
      }
      if (per_match) {
        const zuregex_subject *t = &r[next_repl++];
        if (t->na) {
          o->state = -1;
          break;
        }
        if (!append(o, t->ptr, t->len)) {
          oom = 1;
          break;
        }
      } else {
        int e = expand(p, s, start, options, md, tmpl, syntax, o, &status[i]);
        if (e == 0) {
          oom = 1;
          break;
        }
        if (e < 0) {
          o->state = -1;
          break;
        }
      }
      if (m1 > last) last = m1;
      if (!zuregex_next_start(p, s, md, 0, &start, &options)) break;
    }
    if (o->state == 1 && !expand_flag && !oom) {
      if (!append(o, s->ptr + last, s->len > last ? s->len - last : 0)) oom = 1;
    }
  }
  pcre2_match_data_free(md);
  if (oom) {
    free_out(&job);
    Rf_error("out of memory building replacements");
  }

  SEXP err = PROTECT(zuregex_status_error(&call, status));
  SEXP value = R_NilValue;
  if (Rf_isNull(err)) {
    value = R_ExecWithCleanup(build, &job, free_out, &job);
  } else {
    free_out(&job);
  }
  PROTECT(value);
  SEXP ans = zuregex_result(value, err);
  UNPROTECT(2);
  return ans;
}

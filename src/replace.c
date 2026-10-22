// re_replace() and re_expand().
//
// Matches are found with the same iteration as every other verb
// (zuregex_next_start()). Each match's replacement text comes either from
// pcre2_substitute() with PCRE2_SUBSTITUTE_MATCHED and
// PCRE2_SUBSTITUTE_REPLACEMENT_ONLY, which expands the template against the
// match just found without searching again, or, for a replacement function,
// from the strings it returned. The output is assembled in phase 2 in the
// thread's arena and turned into R strings in phase 3.

#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include "zuregex.h"
#include "match.h"
#include "omp.h"

typedef struct {
  int state;   // 0 unchanged (no match), 1 built, -1 NA
  int tid;     // the arena holding the text
  size_t off;  // where in it
  size_t len;
} out_buf;

typedef struct {
  zuregex_call *call;
  out_buf *out;
  zuregex_arena *arenas;
  int nt;
  SEXP x;     // to return unmatched elements unchanged
  int expand;
  R_xlen_t nul_element;  // first result with a NUL byte, 1-based
  R_xlen_t long_element;  // first result over INT_MAX bytes, 1-based
} replace_job;

// Appends n bytes to the element being built, the last thing in arena a.
static int append(zuregex_arena *a, const char *s, size_t n) {
  if (!zuregex_arena_reserve(a, n)) return 0;
  if (n > 0) memcpy(a->data + a->len, s, n);
  a->len += n;
  return 1;
}

static void free_out(void *data) {
  replace_job *job = data;
  zuregex_arenas_free(job->arenas, job->nt);
  job->arenas = NULL;
  free(job->out);
  job->out = NULL;
}

// Expands `tmpl` against the match in `md`, found at `start` with
// `options`, appending the text to arena `a`. Returns 1, 0 for out of
// memory, or -1 with the error in *st.
static int expand(const zuregex_pattern *p, const zuregex_subject *s,
                  size_t start, uint32_t options, pcre2_match_data *md,
                  const zuregex_subject *tmpl, uint32_t syntax,
                  zuregex_arena *a, zuregex_status *st) {
  uint32_t sub = options | syntax | PCRE2_SUBSTITUTE_MATCHED |
                 PCRE2_SUBSTITUTE_REPLACEMENT_ONLY |
                 PCRE2_SUBSTITUTE_UNSET_EMPTY | PCRE2_SUBSTITUTE_OVERFLOW_LENGTH;
  // Room for the template's own length is usually enough; if not, PCRE2
  // says how much it needs (PCRE2_SUBSTITUTE_OVERFLOW_LENGTH) and the call
  // is repeated once with that much.
  PCRE2_SIZE need = tmpl->len + 64;
  for (int attempt = 0; attempt < 2; attempt++) {
    // One byte more than PCRE2 may write: it NUL-terminates.
    if (!zuregex_arena_reserve(a, need + 1)) return 0;
    PCRE2_SIZE outlen = need + 1;
    int rc = pcre2_substitute(p->code, (PCRE2_SPTR) s->ptr, s->len, start,
                              sub, md, NULL, (PCRE2_SPTR) tmpl->ptr,
                              tmpl->len, (PCRE2_UCHAR *) a->data + a->len,
                              &outlen);
    if (rc >= 0) {
      a->len += outlen;
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
    // An empty result can leave its arena unallocated: point it at "".
    const char *text = "";
    if (o->state == 1 && o->len > 0) text = job->arenas[o->tid].data + o->off;
    if (o->state < 0 || (job->expand && o->state == 0)) {
      SET_STRING_ELT(res, i, NA_STRING);
    } else if (o->state == 0) {
      // No match: the element as it was, in its own encoding. Only a
      // character vector reaches here; raw input is always rebuilt.
      if (TYPEOF(job->x) == STRSXP) {
        SET_STRING_ELT(res, i, STRING_ELT(job->x, i));
      } else {
        const zuregex_subject *s = &call->subjects[i];
        if (memchr(s->ptr, 0, s->len) != NULL) {
          if (job->nul_element == 0) job->nul_element = i + 1;
          SET_STRING_ELT(res, i, NA_STRING);
        } else {
          SET_STRING_ELT(res, i, Rf_mkCharLenCE(s->ptr, (int) s->len, CE_BYTES));
        }
      }
    } else if (o->len > (size_t) INT_MAX) {
      if (job->long_element == 0) job->long_element = i + 1;
      SET_STRING_ELT(res, i, NA_STRING);
    } else if (memchr(text, 0, o->len) != NULL) {
      if (job->nul_element == 0) job->nul_element = i + 1;
      SET_STRING_ELT(res, i, NA_STRING);
    } else {
      const zuregex_pattern *p = zuregex_pattern_for(call, i);
      int utf = p != NULL ? p->key.utf : 1;
      SET_STRING_ELT(res, i, Rf_mkCharLenCE(text, (int) o->len,
                                            utf ? CE_UTF8 : CE_BYTES));
    }
  }
  UNPROTECT(1);
  return res;
}

// mode 0: `repl` holds templates, one or one per element, expanded with
// `syntax`. mode 1: `repl` holds one string per match from a replacement
// function, and first[i] is the 0-based position of element i's first
// string, NA for an element that gives NA. expand: return only the first
// match's expansion.
SEXP zuregex_replace_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                       SEXP repl, SEXP mode, SEXP literal, SEXP n_max,
                       SEXP expand_only, SEXP first) {
  zuregex_call call;
  int is_bytes = Rf_asLogical(bytes);
  zuregex_collect(x, is_bytes, table, index, limits, &call);
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
  int nt = zuregex_threads_for(&call);
  replace_job job = {&call, NULL, NULL, nt, x, expand_flag, 0, 0};
  job.out = calloc(n, sizeof(out_buf));
  job.arenas = zuregex_arenas_new(nt);
  if (job.out == NULL || job.arenas == NULL) {
    free_out(&job);
    Rf_error("out of memory allocating replacement buffers");
  }

  // Phase 2: no R API, on several threads. Running out of memory is an
  // element's error, so threads share no flag.
  const int *first_repl = per_match ? INTEGER(first) : NULL;
  ZUREGEX_OMP_PARALLEL
  {
    pcre2_match_data *md = pcre2_match_data_create(call.max_ovector, NULL);
    zuregex_pad_buf pad = {NULL, 0};
    zuregex_arena *a = &job.arenas[ZUREGEX_THREAD_NUM];
    ZUREGEX_OMP_FOR
    for (R_xlen_t i = 0; i < call.n; i++) {
      const zuregex_pattern *p = zuregex_pattern_for(&call, i);
      out_buf *o = &job.out[i];
      o->tid = ZUREGEX_THREAD_NUM;
      o->off = a->len;
      const zuregex_subject *tmpl = per_match ? NULL : &r[nr == 1 ? 0 : i];
      if (p == NULL || (tmpl != NULL && tmpl->na) ||
          (per_match && first_repl[i] == NA_INTEGER)) {
        o->state = -1;
        continue;
      }
      if (md == NULL) {
        status[i].rc = PCRE2_ERROR_NOMEMORY;
        o->state = -1;
        continue;
      }
      R_xlen_t next_repl = per_match ? first_repl[i] : 0;
      zuregex_subject padded;
      if (!zuregex_pad(&call.subjects[i], &pad, &padded)) {
        status[i].rc = PCRE2_ERROR_NOMEMORY;
        o->state = -1;
        continue;
      }
      const zuregex_subject *s = &padded;
      size_t start = 0, last = 0;
      uint32_t options = 0;
      int matches = 0, oom = 0;
      while (matches < limit) {
        int m = zuregex_match_once(&call, p, s, start, options, md, &status[i]);
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
            !append(a, s->ptr + last, m0 - last)) {
          oom = 1;
          break;
        }
        if (per_match) {
          if (next_repl >= nr) {
            // The first pass found fewer matches than this one: cannot
            // happen with the same pattern, subject and limits.
            o->state = -1;
            break;
          }
          const zuregex_subject *t = &r[next_repl++];
          if (t->na) {
            o->state = -1;
            break;
          }
          if (!append(a, t->ptr, t->len)) {
            oom = 1;
            break;
          }
        } else {
          int e = expand(p, s, start, options, md, tmpl, syntax, a, &status[i]);
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
      if (!oom && o->state == 1 && !expand_flag &&
          !append(a, s->ptr + last, s->len > last ? s->len - last : 0)) {
        oom = 1;
      }
      if (oom) {
        status[i].rc = PCRE2_ERROR_NOMEMORY;
        o->state = -1;
      }
      // Only a built element keeps its text.
      if (o->state == 1) {
        o->len = a->len - o->off;
      } else {
        a->len = o->off;
      }
    }
    pcre2_match_data_free(md);
    free(pad.data);
  }

  SEXP err = PROTECT(zuregex_status_error(&call, status));
  SEXP value = R_NilValue;
  if (Rf_isNull(err)) {
    value = R_ExecWithCleanup(build, &job, free_out, &job);
    if (job.long_element > 0 || job.nul_element > 0) {
      UNPROTECT(1);
      err = PROTECT(job.long_element > 0 ? zuregex_too_long_error(job.long_element)
                                         : zuregex_nul_error(job.nul_element));
      value = R_NilValue;
    }
  } else {
    free_out(&job);
  }
  PROTECT(value);
  SEXP ans = zuregex_result(&call, status, value, err);
  UNPROTECT(2);
  return ans;
}

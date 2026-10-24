// re_locate() and re_locate_all().
//
// Offsets leave here one-based and inclusive, in characters or bytes
// (design section 6.2): a match of bytes [b0, b1) is start = b0 + 1,
// end = b1, converted to characters when asked. An empty match at k is
// start = k, end = k - 1.

#include <stdlib.h>
#include <string.h>

#include "zuregex.h"
#include "match.h"
#include "omp.h"

// A position in one subject, in bytes and in characters, so converting
// the next offset counts only the bytes between the two.
typedef struct {
  size_t byte;
  size_t chars;
} cursor;

static int to_offset(const zuregex_subject *s, size_t byte, int chars,
                     int utf, cursor *at) {
  if (!chars || !utf || s->ascii) return (int) byte;
  // Offsets mostly move forward; overlap and \K can move them back.
  if (byte >= at->byte) {
    at->chars += zuregex_chars(s->ptr + at->byte, byte - at->byte, utf);
  } else {
    at->chars -= zuregex_chars(s->ptr + byte, at->byte - byte, utf);
  }
  at->byte = byte;
  return (int) at->chars;
}

static zuregex_status *new_status(R_xlen_t n) {
  size_t m = n > 0 ? (size_t) n : 1;
  zuregex_status *st = (zuregex_status *) R_alloc(m, sizeof(zuregex_status));
  memset(st, 0, m * sizeof(zuregex_status));
  return st;
}

SEXP zuregex_locate_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                      SEXP char_offsets) {
  zuregex_call call;
  ZUREGEX_COLLECT(x, Rf_asLogical(bytes), table, index, limits, &call);
  int chars = Rf_asLogical(char_offsets);

  SEXP out = PROTECT(Rf_allocMatrix(INTSXP, (int) call.n, 2));
  SEXP dn = PROTECT(Rf_allocVector(VECSXP, 2));
  SEXP cn = Rf_allocVector(STRSXP, 2);
  SET_VECTOR_ELT(dn, 1, cn);
  SET_STRING_ELT(cn, 0, Rf_mkChar("start"));
  SET_STRING_ELT(cn, 1, Rf_mkChar("end"));
  Rf_dimnamesgets(out, dn);
  UNPROTECT(1);
  int *start_col = INTEGER(out);
  int *end_col = start_col + call.n;
  zuregex_status *status = new_status(call.n);

  // Phase 2.
  int nt = zuregex_threads_for(&call);
  ZUREGEX_OMP_PARALLEL
  {
    pcre2_match_data *md = pcre2_match_data_create(call.max_ovector, NULL);
    zuregex_pad_buf pad = {NULL, 0};
    ZUREGEX_FOR_EACH(i, call.n) {
      const zuregex_pattern *p = zuregex_pattern_for(&call, i);
      start_col[i] = end_col[i] = NA_INTEGER;
      if (p == NULL) continue;
      if (md == NULL) {
        status[i].rc = PCRE2_ERROR_NOMEMORY;
        continue;
      }
      zuregex_subject padded;
      if (!zuregex_pad(&call.subjects[i], &pad, &padded)) {
        status[i].rc = PCRE2_ERROR_NOMEMORY;
        continue;
      }
      const zuregex_subject *s = &padded;
      if (zuregex_match_once(&call, p, s, 0, 0, md, &status[i]) != 1) continue;
      PCRE2_SIZE *ov = pcre2_get_ovector_pointer(md);
      cursor at = {0, 0};
      start_col[i] = to_offset(s, ov[0], chars, p->key.utf, &at) + 1;
      end_col[i] = to_offset(s, ov[1], chars, p->key.utf, &at);
    }
    pcre2_match_data_free(md);
    free(pad.data);
  }

  SEXP err = PROTECT(zuregex_status_error(&call, status));
  SEXP ans = zuregex_result(&call, status, Rf_isNull(err) ? out : R_NilValue, err);
  UNPROTECT(2);
  return ans;
}

// The matches of one element, in its phase-2 thread's arena: no R memory,
// so phase 2 stays free of the R API.
typedef struct {
  int count;   // matches; -1 for an NA row (NA subject or pattern)
  int tid;     // the arena holding its offsets
  size_t off;  // where in it: count pairs of int start, end
} element_matches;

typedef struct {
  element_matches *el;
  R_xlen_t n;
  zuregex_arena *arenas;
  int nt;
} matches_table;

static int push_match(element_matches *e, zuregex_arena *a, int start,
                      int end) {
  if (!zuregex_arena_reserve(a, 2 * sizeof(int))) return 0;
  int *dst = (int *) (a->data + a->len);
  dst[0] = start;
  dst[1] = end;
  a->len += 2 * sizeof(int);
  e->count++;
  return 1;
}

static void free_matches(void *data) {
  matches_table *t = data;
  zuregex_arenas_free(t->arenas, t->nt);
  t->arenas = NULL;
  free(t->el);
  t->el = NULL;
}

// Phase 3, run by R_ExecWithCleanup() so the buffers above are freed even
// if an allocation here fails.
static SEXP build_frame(void *data) {
  matches_table *t = data;
  R_xlen_t rows = 0;
  for (R_xlen_t i = 0; i < t->n; i++) {
    rows += t->el[i].count < 0 ? 1 : t->el[i].count;
  }
  const char *names[] = {"element", "match", "start", "end", ""};
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  SEXP element = PROTECT(Rf_allocVector(INTSXP, rows));
  SEXP match = PROTECT(Rf_allocVector(INTSXP, rows));
  SEXP start = PROTECT(Rf_allocVector(INTSXP, rows));
  SEXP end = PROTECT(Rf_allocVector(INTSXP, rows));
  R_xlen_t r = 0;
  for (R_xlen_t i = 0; i < t->n; i++) {
    const element_matches *e = &t->el[i];
    // Only an element with matches has written to its arena.
    const int *offsets =
      e->count > 0 ? (const int *) (t->arenas[e->tid].data + e->off) : NULL;
    if (e->count < 0) {
      INTEGER(element)[r] = (int) i + 1;
      INTEGER(match)[r] = NA_INTEGER;
      INTEGER(start)[r] = NA_INTEGER;
      INTEGER(end)[r] = NA_INTEGER;
      r++;
      continue;
    }
    for (int k = 0; k < e->count; k++, r++) {
      INTEGER(element)[r] = (int) i + 1;
      INTEGER(match)[r] = k + 1;
      INTEGER(start)[r] = offsets[2 * k];
      INTEGER(end)[r] = offsets[2 * k + 1];
    }
  }
  SET_VECTOR_ELT(out, 0, element);
  SET_VECTOR_ELT(out, 1, match);
  SET_VECTOR_ELT(out, 2, start);
  SET_VECTOR_ELT(out, 3, end);
  UNPROTECT(5);
  return out;
}

// n: the most matches per element (R_PosInf for all). overlap: start each
// search one character after the previous match's start.
SEXP zuregex_locate_all_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                          SEXP n_max, SEXP overlap, SEXP char_offsets) {
  zuregex_call call;
  ZUREGEX_COLLECT(x, Rf_asLogical(bytes), table, index, limits, &call);
  double limit = Rf_asReal(n_max);
  int ov_flag = Rf_asLogical(overlap);
  int chars = Rf_asLogical(char_offsets);
  zuregex_status *status = new_status(call.n);

  int nt = zuregex_threads_for(&call);
  matches_table t = {NULL, call.n, NULL, nt};
  t.el = calloc(call.n > 0 ? (size_t) call.n : 1, sizeof(element_matches));
  t.arenas = zuregex_arenas_new(nt);
  if (t.el == NULL || t.arenas == NULL) {
    free_matches(&t);
    Rf_error("out of memory allocating match buffers");
  }

  // Phase 2. Running out of memory is an element's error, so threads share
  // no flag.
  ZUREGEX_OMP_PARALLEL
  {
    pcre2_match_data *md = pcre2_match_data_create(call.max_ovector, NULL);
    zuregex_pad_buf pad = {NULL, 0};
    zuregex_arena *a = &t.arenas[ZUREGEX_THREAD_NUM];
    ZUREGEX_FOR_EACH(i, call.n) {
      const zuregex_pattern *p = zuregex_pattern_for(&call, i);
      element_matches *e = &t.el[i];
      e->tid = ZUREGEX_THREAD_NUM;
      e->off = a->len;
      if (p == NULL) {
        e->count = -1;
        continue;
      }
      if (md == NULL) {
        status[i].rc = PCRE2_ERROR_NOMEMORY;
        e->count = -1;
        continue;
      }
      zuregex_subject padded;
      if (!zuregex_pad(&call.subjects[i], &pad, &padded)) {
        status[i].rc = PCRE2_ERROR_NOMEMORY;
        e->count = -1;
        continue;
      }
      const zuregex_subject *s = &padded;
      size_t start = 0;
      uint32_t options = 0;
      cursor at = {0, 0};
      while (e->count < limit) {
        int m = zuregex_match_once(&call, p, s, start, options, md, &status[i]);
        if (m < 0) {
          // An error or a limit: the element is NA, not a partial result.
          e->count = -1;
          break;
        }
        if (m == 0) break;
        PCRE2_SIZE *ov = pcre2_get_ovector_pointer(md);
        int from = to_offset(s, ov[0], chars, p->key.utf, &at) + 1;
        int to = to_offset(s, ov[1], chars, p->key.utf, &at);
        if (!push_match(e, a, from, to)) {
          status[i].rc = PCRE2_ERROR_NOMEMORY;
          e->count = -1;
          break;
        }
        if (!zuregex_next_start(p, s, md, ov_flag, &start, &options)) break;
      }
      // An NA element keeps none of its matches.
      if (e->count < 0) a->len = e->off;
    }
    pcre2_match_data_free(md);
    free(pad.data);
  }

  SEXP err = PROTECT(zuregex_status_error(&call, status));
  SEXP frame = R_NilValue;
  if (Rf_isNull(err)) {
    frame = R_ExecWithCleanup(build_frame, &t, free_matches, &t);
  } else {
    free_matches(&t);
  }
  PROTECT(frame);
  SEXP ans = zuregex_result(&call, status, frame, err);
  UNPROTECT(2);
  return ans;
}

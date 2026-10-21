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

static int to_offset(const zuregex_subject *s, size_t byte, int chars,
                     int utf) {
  size_t v = chars ? zuregex_chars(s->ptr, byte, utf) : byte;
  return (int) v;
}

static zuregex_status *new_status(R_xlen_t n) {
  size_t m = n > 0 ? (size_t) n : 1;
  zuregex_status *st = (zuregex_status *) R_alloc(m, sizeof(zuregex_status));
  memset(st, 0, m * sizeof(zuregex_status));
  return st;
}

SEXP zuregex_locate_c(SEXP x, SEXP bytes, SEXP table, SEXP index,
                      SEXP char_offsets) {
  zuregex_call call;
  zuregex_collect(x, Rf_asLogical(bytes), table, index, &call);
  int chars = Rf_asLogical(char_offsets);

  SEXP out = PROTECT(Rf_allocMatrix(INTSXP, (int) call.n, 2));
  int *start_col = INTEGER(out);
  int *end_col = start_col + call.n;
  zuregex_status *status = new_status(call.n);
  pcre2_match_data *md = pcre2_match_data_create(call.max_ovector, NULL);
  if (md == NULL) Rf_error("out of memory allocating match data");

  // Phase 2.
  for (R_xlen_t i = 0; i < call.n; i++) {
    const zuregex_pattern *p = zuregex_pattern_for(&call, i);
    start_col[i] = end_col[i] = NA_INTEGER;
    if (p == NULL) continue;
    const zuregex_subject *s = &call.subjects[i];
    if (zuregex_match_once(p, s, 0, 0, md, &status[i]) != 1) continue;
    PCRE2_SIZE *ov = pcre2_get_ovector_pointer(md);
    start_col[i] = to_offset(s, ov[0], chars, p->key.utf) + 1;
    end_col[i] = to_offset(s, ov[1], chars, p->key.utf);
  }
  pcre2_match_data_free(md);

  SEXP err = PROTECT(zuregex_status_error(&call, status));
  SEXP ans = zuregex_result(Rf_isNull(err) ? out : R_NilValue, err);
  UNPROTECT(2);
  return ans;
}

// The matches of one element, grown with realloc() in phase 2: no R
// memory, so phase 2 stays free of the R API.
typedef struct {
  int count;  // matches; -1 for an NA row (NA subject or pattern)
  int cap;
  int *offsets;  // count pairs of start, end
} element_matches;

typedef struct {
  element_matches *el;
  R_xlen_t n;
} matches_table;

static int push_match(element_matches *e, int start, int end) {
  if (e->count == e->cap) {
    int cap = e->cap ? e->cap * 2 : 4;
    int *grown = realloc(e->offsets, (size_t) cap * 2 * sizeof(int));
    if (grown == NULL) return 0;
    e->offsets = grown;
    e->cap = cap;
  }
  e->offsets[2 * e->count] = start;
  e->offsets[2 * e->count + 1] = end;
  e->count++;
  return 1;
}

static void free_matches(void *data) {
  matches_table *t = data;
  if (t->el == NULL) return;
  for (R_xlen_t i = 0; i < t->n; i++) free(t->el[i].offsets);
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
      INTEGER(start)[r] = e->offsets[2 * k];
      INTEGER(end)[r] = e->offsets[2 * k + 1];
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
SEXP zuregex_locate_all_c(SEXP x, SEXP bytes, SEXP table, SEXP index,
                          SEXP n_max, SEXP overlap, SEXP char_offsets) {
  zuregex_call call;
  zuregex_collect(x, Rf_asLogical(bytes), table, index, &call);
  double limit = Rf_asReal(n_max);
  int ov_flag = Rf_asLogical(overlap);
  int chars = Rf_asLogical(char_offsets);
  zuregex_status *status = new_status(call.n);

  matches_table t = {NULL, call.n};
  t.el = calloc(call.n > 0 ? (size_t) call.n : 1, sizeof(element_matches));
  pcre2_match_data *md = pcre2_match_data_create(call.max_ovector, NULL);
  if (t.el == NULL || md == NULL) {
    free(t.el);
    pcre2_match_data_free(md);
    Rf_error("out of memory allocating match buffers");
  }

  // Phase 2.
  int oom = 0;
  for (R_xlen_t i = 0; i < call.n && !oom; i++) {
    const zuregex_pattern *p = zuregex_pattern_for(&call, i);
    element_matches *e = &t.el[i];
    if (p == NULL) {
      e->count = -1;
      continue;
    }
    const zuregex_subject *s = &call.subjects[i];
    size_t start = 0;
    uint32_t options = 0;
    while (e->count < limit) {
      int m = zuregex_match_once(p, s, start, options, md, &status[i]);
      if (m != 1) break;
      PCRE2_SIZE *ov = pcre2_get_ovector_pointer(md);
      if (!push_match(e, to_offset(s, ov[0], chars, p->key.utf) + 1,
                      to_offset(s, ov[1], chars, p->key.utf))) {
        oom = 1;
        break;
      }
      if (!zuregex_next_start(p, s, md, ov_flag, &start, &options)) break;
    }
  }
  pcre2_match_data_free(md);
  if (oom) {
    free_matches(&t);
    Rf_error("out of memory collecting matches");
  }

  SEXP err = PROTECT(zuregex_status_error(&call, status));
  SEXP frame = R_NilValue;
  if (Rf_isNull(err)) {
    frame = R_ExecWithCleanup(build_frame, &t, free_matches, &t);
  } else {
    free_matches(&t);
  }
  PROTECT(frame);
  SEXP ans = zuregex_result(frame, err);
  UNPROTECT(2);
  return ans;
}

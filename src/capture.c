// re_extract(), re_extract_all(), re_match() and re_match_all().
//
// Phase 2 scans each element and keeps the offsets of every group of every
// match in its thread's arena. Phase 3, under R_ExecWithCleanup(), turns
// offset pairs into strings through make_string(), the one place a CHARSXP
// is made from a match, so encoding is decided once.

#include <stdlib.h>
#include <string.h>

#include "zuregex.h"
#include "match.h"
#include "omp.h"

typedef struct {
  int count;          // matches; -1 for an NA subject or pattern
  int tid;            // the arena holding its offsets
  size_t off;         // where in it: count * width pairs of PCRE2_SIZE
} element_caps;

typedef struct {
  zuregex_call *call;
  element_caps *el;
  zuregex_arena *arenas;  // one per phase-2 thread
  int nt;
  int may_nul;        // raw input: text can hold a NUL byte
  uint32_t width;     // pairs per match: groups + 1 of the widest pattern
  // What phase 3 builds, set by the entry points.
  SEXP groups;        // re_extract*: per pattern table entry, the group
                      // numbers to try in order (several for a name that
                      // J shares); empty where that pattern has none
  R_xlen_t nul_element;  // first element whose text holds a NUL byte, 1-based
  int keep_groups;    // re_split(): keep each separator's groups
  SEXP colmap;        // re_match*: per pattern, the column of each group
  int ncol;
  int all;
  int with_zero;      // re_match*: colmap starts with group 0
} capture_job;

static void free_caps(void *data) {
  capture_job *job = data;
  zuregex_arenas_free(job->arenas, job->nt);
  job->arenas = NULL;
  free(job->el);
  job->el = NULL;
}

// Element e's offsets, valid once phase 2 is over.
static const PCRE2_SIZE *caps_of(const capture_job *job, const element_caps *e) {
  return (const PCRE2_SIZE *) (job->arenas[e->tid].data + e->off);
}

// The pattern table entry (0-based) element i uses, or -1.
static int entry_for(const zuregex_call *call, R_xlen_t i) {
  if (call->subjects[i].na) return -1;
  int k = call->index[call->index_len == 1 ? 0 : i];
  return k == NA_INTEGER ? -1 : k - 1;
}

// Appends one match to the element being scanned, which is the last thing
// in arena a.
static int push(element_caps *e, zuregex_arena *a, const PCRE2_SIZE *ov,
                uint32_t pairs, uint32_t width) {
  size_t bytes = (size_t) width * 2 * sizeof(PCRE2_SIZE);
  if (!zuregex_arena_reserve(a, bytes)) return 0;
  PCRE2_SIZE *dst = (PCRE2_SIZE *) (a->data + a->len);
  a->len += bytes;
  for (uint32_t g = 0; g < width; g++) {
    if (g < pairs) {
      dst[2 * g] = ov[2 * g];
      dst[2 * g + 1] = ov[2 * g + 1];
    } else {
      dst[2 * g] = dst[2 * g + 1] = PCRE2_UNSET;
    }
  }
  e->count++;
  return 1;
}

// Phase 2: no R API, on several threads. Running out of memory is an
// element's error, so threads share no flag.
static void scan(capture_job *job, double limit, zuregex_status *status) {
  zuregex_call *call = job->call;
  int nt = job->nt;
  ZUREGEX_OMP_PARALLEL
  {
    pcre2_match_data *md = pcre2_match_data_create(job->width, NULL);
    zuregex_pad_buf pad = {NULL, 0};
    zuregex_arena *a = &job->arenas[ZUREGEX_THREAD_NUM];
    ZUREGEX_OMP_FOR
    for (R_xlen_t i = 0; i < call->n; i++) {
      const zuregex_pattern *p = zuregex_pattern_for(call, i);
      element_caps *e = &job->el[i];
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
      if (!zuregex_pad(&call->subjects[i], &pad, &padded)) {
        status[i].rc = PCRE2_ERROR_NOMEMORY;
        e->count = -1;
        continue;
      }
      const zuregex_subject *s = &padded;
      uint32_t pairs = 0;
      pcre2_pattern_info(p->code, PCRE2_INFO_CAPTURECOUNT, &pairs);
      pairs += 1;
      size_t start = 0;
      uint32_t options = 0;
      while (e->count < limit) {
        int m = zuregex_match_once(call, p, s, start, options, md, &status[i]);
        if (m < 0) {
          // An error or a limit: the element is NA, not a partial result.
          e->count = -1;
          break;
        }
        if (m == 0) break;
        if (!push(e, a, pcre2_get_ovector_pointer(md), pairs, job->width)) {
          status[i].rc = PCRE2_ERROR_NOMEMORY;
          e->count = -1;
          break;
        }
        if (!zuregex_next_start(p, s, md, 0, &start, &options)) break;
      }
      // An NA element keeps none of its matches.
      if (e->count < 0) a->len = e->off;
    }
    pcre2_match_data_free(md);
    free(pad.data);
  }
}

// The one place a match becomes an R string. Character input is matched
// as UTF-8, so its matches are marked UTF-8; bytes in, bytes out. R drops
// the mark for ASCII. An unset group is NA. Text with a NUL byte, possible
// from raw input, cannot be an R string: the element is recorded in the job
// and run() raises a classed error instead of R's own.
static SEXP make_string(capture_job *job, R_xlen_t i, const zuregex_subject *s,
                        PCRE2_SIZE a, PCRE2_SIZE b, int utf) {
  if (a == PCRE2_UNSET || b == PCRE2_UNSET) return NA_STRING;
  // \K in a lookahead can end a match before its start: PCRE2 reports
  // that as is, and the matched text is empty.
  if (b < a) return R_BlankString;
  // An R string cannot hold a NUL, so only raw input needs the scan.
  if (job->may_nul && memchr(s->ptr + a, 0, b - a) != NULL) {
    if (job->nul_element == 0) job->nul_element = i + 1;
    return NA_STRING;
  }
  return Rf_mkCharLenCE(s->ptr + a, (int) (b - a), utf ? CE_UTF8 : CE_BYTES);
}

// The group to read for pattern entry k in a match: the first candidate
// that took part, or the first candidate (unset, so NA) if none did; -1
// when the pattern has no candidate.
static int pick_group(const capture_job *job, int k, const PCRE2_SIZE *ov) {
  if (k < 0) return -1;
  SEXP cand = VECTOR_ELT(job->groups, k);
  int n = LENGTH(cand);
  if (n == 0) return -1;
  const int *g = INTEGER(cand);
  for (int j = 0; j < n; j++) {
    if (ov[2 * g[j]] != PCRE2_UNSET) return g[j];
  }
  return g[0];
}

static int utf_of(const zuregex_call *call, int k) {
  return k >= 0 ? call->patterns[k]->key.utf : 1;
}

// re_extract(): one string per element. re_extract_all(): a list with a
// character vector per element.
static SEXP build_extract(void *data) {
  capture_job *job = data;
  zuregex_call *call = job->call;
  SEXP out;
  if (!job->all) {
    out = PROTECT(Rf_allocVector(STRSXP, call->n));
    for (R_xlen_t i = 0; i < call->n; i++) {
      int k = entry_for(call, i);
      element_caps *e = &job->el[i];
      int g = e->count > 0 ? pick_group(job, k, caps_of(job, e)) : -1;
      if (g < 0) {
        SET_STRING_ELT(out, i, NA_STRING);
        continue;
      }
      const PCRE2_SIZE *ov = caps_of(job, e);
      SET_STRING_ELT(out, i, make_string(job, i, &call->subjects[i],
                                         ov[2 * g], ov[2 * g + 1],
                                         utf_of(call, k)));
    }
    UNPROTECT(1);
    return out;
  }
  out = PROTECT(Rf_allocVector(VECSXP, call->n));
  for (R_xlen_t i = 0; i < call->n; i++) {
    int k = entry_for(call, i);
    element_caps *e = &job->el[i];
    int has = k >= 0 && LENGTH(VECTOR_ELT(job->groups, k)) > 0;
    if (e->count < 0) {
      SET_VECTOR_ELT(out, i, Rf_ScalarString(NA_STRING));
      continue;
    }
    if (!has) {
      // The element's pattern has no such group: NA for each match.
      SEXP v = PROTECT(Rf_allocVector(STRSXP, e->count));
      for (int m = 0; m < e->count; m++) SET_STRING_ELT(v, m, NA_STRING);
      SET_VECTOR_ELT(out, i, v);
      UNPROTECT(1);
      continue;
    }
    SEXP v = PROTECT(Rf_allocVector(STRSXP, e->count));
    for (int m = 0; m < e->count; m++) {
      const PCRE2_SIZE *ov = caps_of(job, e) + (size_t) m * job->width * 2;
      int g = pick_group(job, k, ov);
      SET_STRING_ELT(v, m, make_string(job, i, &call->subjects[i], ov[2 * g],
                                       ov[2 * g + 1], utf_of(call, k)));
    }
    SET_VECTOR_ELT(out, i, v);
    UNPROTECT(1);
  }
  UNPROTECT(1);
  return out;
}

// re_match(): ncol columns of one row per element. re_match_all(): element
// and match columns, then the groups, one row per match.
static SEXP build_match(void *data) {
  capture_job *job = data;
  zuregex_call *call = job->call;
  R_xlen_t rows = 0;
  for (R_xlen_t i = 0; i < call->n; i++) {
    if (!job->all) {
      rows++;
    } else {
      rows += job->el[i].count < 0 ? 1 : job->el[i].count;
    }
  }
  int lead = job->all ? 2 : 0;
  SEXP out = PROTECT(Rf_allocVector(VECSXP, job->ncol + lead));
  for (int c = 0; c < job->ncol; c++) {
    SEXP col = Rf_allocVector(STRSXP, rows);
    SET_VECTOR_ELT(out, c + lead, col);
    for (R_xlen_t r = 0; r < rows; r++) SET_STRING_ELT(col, r, NA_STRING);
  }
  int *element = NULL, *match = NULL;
  if (job->all) {
    SET_VECTOR_ELT(out, 0, Rf_allocVector(INTSXP, rows));
    SET_VECTOR_ELT(out, 1, Rf_allocVector(INTSXP, rows));
    element = INTEGER(VECTOR_ELT(out, 0));
    match = INTEGER(VECTOR_ELT(out, 1));
  }
  R_xlen_t r = 0;
  for (R_xlen_t i = 0; i < call->n; i++) {
    int k = entry_for(call, i);
    element_caps *e = &job->el[i];
    if (e->count < 0 || (!job->all && e->count == 0)) {
      if (job->all) {
        element[r] = (int) i + 1;
        match[r] = NA_INTEGER;
      }
      r++;
      continue;
    }
    SEXP map = VECTOR_ELT(job->colmap, k);
    const int *cols = INTEGER(map);
    int entries = LENGTH(map);
    int first = job->with_zero ? 0 : 1;  // the group colmap's entry 0 is for
    int utf = utf_of(call, k);
    for (int m = 0; m < e->count; m++, r++) {
      const PCRE2_SIZE *ov = caps_of(job, e) + (size_t) m * job->width * 2;
      if (job->all) {
        element[r] = (int) i + 1;
        match[r] = m + 1;
      }
      for (int j = 0; j < entries; j++) {
        int g = j + first;
        SEXP col = VECTOR_ELT(out, cols[j] - 1 + lead);
        // Groups that share a name (J) share a column: the first one that
        // took part fills it, which is PCRE2's own rule for ${name}.
        if (STRING_ELT(col, r) != NA_STRING) continue;
        SET_STRING_ELT(col, r, make_string(job, i, &call->subjects[i],
                                           ov[2 * g], ov[2 * g + 1], utf));
      }
    }
  }
  UNPROTECT(1);
  return out;
}

// re_split(): pieces between matches, as Python's re.split() makes them,
// with each separator's groups between the pieces when asked.
static SEXP build_split(void *data) {
  capture_job *job = data;
  zuregex_call *call = job->call;
  SEXP out = PROTECT(Rf_allocVector(VECSXP, call->n));
  for (R_xlen_t i = 0; i < call->n; i++) {
    element_caps *e = &job->el[i];
    if (e->count < 0) {
      SET_VECTOR_ELT(out, i, Rf_ScalarString(NA_STRING));
      continue;
    }
    int k = entry_for(call, i);
    int utf = utf_of(call, k);
    uint32_t groups = 0;
    pcre2_pattern_info(call->patterns[k]->code, PCRE2_INFO_CAPTURECOUNT, &groups);
    R_xlen_t len = (R_xlen_t) e->count + 1;
    if (job->keep_groups) len += (R_xlen_t) e->count * groups;
    SEXP v = PROTECT(Rf_allocVector(STRSXP, len));
    const zuregex_subject *s = &call->subjects[i];
    PCRE2_SIZE last = 0;
    R_xlen_t at = 0;
    for (int m = 0; m < e->count; m++) {
      const PCRE2_SIZE *ov = caps_of(job, e) + (size_t) m * job->width * 2;
      PCRE2_SIZE from = last, to = ov[0] > last ? ov[0] : last;
      SET_STRING_ELT(v, at++, make_string(job, i, s, from, to, utf));
      if (job->keep_groups) {
        for (uint32_t g = 1; g <= groups; g++) {
          SET_STRING_ELT(v, at++, make_string(job, i, s, ov[2 * g], ov[2 * g + 1], utf));
        }
      }
      if (ov[1] > last) last = ov[1];
    }
    SET_STRING_ELT(v, at, make_string(job, i, s, last, s->len, utf));
    SET_VECTOR_ELT(out, i, v);
    UNPROTECT(1);
  }
  UNPROTECT(1);
  return out;
}

static SEXP run(capture_job *job, double limit, SEXP (*build)(void *)) {
  zuregex_call *call = job->call;
  size_t n = call->n > 0 ? (size_t) call->n : 1;
  zuregex_status *status = (zuregex_status *) R_alloc(n, sizeof(zuregex_status));
  memset(status, 0, n * sizeof(zuregex_status));
  job->width = call->max_ovector;
  job->nt = zuregex_threads_for(call);
  job->el = calloc(n, sizeof(element_caps));
  job->arenas = zuregex_arenas_new(job->nt);
  if (job->el == NULL || job->arenas == NULL) {
    free_caps(job);
    Rf_error("out of memory allocating match buffers");
  }
  scan(job, limit, status);
  SEXP err = PROTECT(zuregex_status_error(call, status));
  SEXP value = R_NilValue;
  if (Rf_isNull(err)) {
    value = R_ExecWithCleanup(build, job, free_caps, job);
    if (job->nul_element > 0) {
      UNPROTECT(1);
      err = PROTECT(zuregex_nul_error(job->nul_element));
      value = R_NilValue;
    }
  } else {
    free_caps(job);
  }
  PROTECT(value);
  SEXP ans = zuregex_result(call, status, value, err);
  UNPROTECT(2);
  return ans;
}

// group: per pattern table entry, an integer vector of the groups to try
// in order (0 is the whole match), empty where that pattern has none.
SEXP zuregex_extract_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                       SEXP group, SEXP all, SEXP n_max) {
  zuregex_call call;
  zuregex_collect(x, Rf_asLogical(bytes), table, index, limits, &call);
  capture_job job;
  memset(&job, 0, sizeof(job));
  job.call = &call;
  job.may_nul = TYPEOF(x) != STRSXP;
  job.groups = group;
  job.all = Rf_asLogical(all);
  return run(&job, job.all ? Rf_asReal(n_max) : 1, build_extract);
}

// colmap: per pattern table entry, an integer vector giving the 1-based
// output column of each of its groups, preceded by group 0's column when
// with_zero is TRUE.
SEXP zuregex_match_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                     SEXP colmap, SEXP ncol, SEXP all, SEXP n_max,
                     SEXP with_zero) {
  zuregex_call call;
  zuregex_collect(x, Rf_asLogical(bytes), table, index, limits, &call);
  capture_job job;
  memset(&job, 0, sizeof(job));
  job.call = &call;
  job.may_nul = TYPEOF(x) != STRSXP;
  job.colmap = colmap;
  job.ncol = Rf_asInteger(ncol);
  job.all = Rf_asLogical(all);
  job.with_zero = Rf_asLogical(with_zero);
  return run(&job, job.all ? Rf_asReal(n_max) : 1, build_match);
}

// n_max: the most separators to split at (pieces - 1).
SEXP zuregex_split_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                     SEXP n_max, SEXP keep_groups) {
  zuregex_call call;
  zuregex_collect(x, Rf_asLogical(bytes), table, index, limits, &call);
  capture_job job;
  memset(&job, 0, sizeof(job));
  job.call = &call;
  job.may_nul = TYPEOF(x) != STRSXP;
  job.keep_groups = Rf_asLogical(keep_groups);
  return run(&job, Rf_asReal(n_max), build_split);
}

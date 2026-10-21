// re_extract(), re_extract_all(), re_match() and re_match_all().
//
// Phase 2 scans each element and keeps the offsets of every group of every
// match in malloc()ed buffers. Phase 3, under R_ExecWithCleanup(), turns
// offset pairs into strings through make_string(), the one place a CHARSXP
// is made from a match, so encoding is decided once.

#include <stdlib.h>
#include <string.h>

#include "zuregex.h"
#include "match.h"
#include "omp.h"

typedef struct {
  int count;          // matches; -1 for an NA subject or pattern
  int cap;
  PCRE2_SIZE *ov;     // count * width pairs
} element_caps;

typedef struct {
  zuregex_call *call;
  element_caps *el;
  uint32_t width;     // pairs per match: groups + 1 of the widest pattern
  // What phase 3 builds, set by the entry points.
  const int *group;   // re_extract*: group per pattern table entry, -1 none
  int keep_groups;    // re_split(): keep each separator's groups
  SEXP colmap;        // re_match*: per pattern, the column of each group
  int ncol;
  int all;
  int with_zero;      // re_match*: colmap starts with group 0
} capture_job;

static void free_caps(void *data) {
  capture_job *job = data;
  if (job->el == NULL) return;
  for (R_xlen_t i = 0; i < job->call->n; i++) free(job->el[i].ov);
  free(job->el);
  job->el = NULL;
}

// The pattern table entry (0-based) element i uses, or -1.
static int entry_for(const zuregex_call *call, R_xlen_t i) {
  if (call->subjects[i].na) return -1;
  int k = call->index[call->index_len == 1 ? 0 : i];
  return k == NA_INTEGER ? -1 : k - 1;
}

static int push(element_caps *e, const PCRE2_SIZE *ov, uint32_t pairs,
                uint32_t width) {
  if (e->count == e->cap) {
    int cap = e->cap ? e->cap * 2 : 1;
    PCRE2_SIZE *grown = realloc(e->ov, (size_t) cap * width * 2 * sizeof(PCRE2_SIZE));
    if (grown == NULL) return 0;
    e->ov = grown;
    e->cap = cap;
  }
  PCRE2_SIZE *dst = e->ov + (size_t) e->count * width * 2;
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
  int nt = zuregex_threads_for(call);
  ZUREGEX_OMP_PARALLEL
  {
    pcre2_match_data *md = pcre2_match_data_create(job->width, NULL);
    zuregex_pad_buf pad = {NULL, 0};
    ZUREGEX_OMP_FOR
    for (R_xlen_t i = 0; i < call->n; i++) {
      const zuregex_pattern *p = zuregex_pattern_for(call, i);
      element_caps *e = &job->el[i];
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
        if (!push(e, pcre2_get_ovector_pointer(md), pairs, job->width)) {
          status[i].rc = PCRE2_ERROR_NOMEMORY;
          e->count = -1;
          break;
        }
        if (!zuregex_next_start(p, s, md, 0, &start, &options)) break;
      }
    }
    pcre2_match_data_free(md);
    free(pad.data);
  }
}

// The one place a match becomes an R string. Character input is matched
// as UTF-8, so its matches are marked UTF-8; bytes in, bytes out. R drops
// the mark for ASCII. An unset group is NA.
static SEXP make_string(const zuregex_subject *s, PCRE2_SIZE a, PCRE2_SIZE b,
                        int utf) {
  if (a == PCRE2_UNSET || b == PCRE2_UNSET) return NA_STRING;
  // \K in a lookahead can end a match before its start: PCRE2 reports
  // that as is, and the matched text is empty.
  if (b < a) return R_BlankString;
  return Rf_mkCharLenCE(s->ptr + a, (int) (b - a), utf ? CE_UTF8 : CE_BYTES);
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
      int g = k >= 0 ? job->group[k] : -1;
      if (e->count <= 0 || g < 0) {
        SET_STRING_ELT(out, i, NA_STRING);
        continue;
      }
      SET_STRING_ELT(out, i, make_string(&call->subjects[i], e->ov[2 * g],
                                         e->ov[2 * g + 1], utf_of(call, k)));
    }
    UNPROTECT(1);
    return out;
  }
  out = PROTECT(Rf_allocVector(VECSXP, call->n));
  for (R_xlen_t i = 0; i < call->n; i++) {
    int k = entry_for(call, i);
    element_caps *e = &job->el[i];
    int g = k >= 0 ? job->group[k] : -1;
    if (e->count < 0) {
      SET_VECTOR_ELT(out, i, Rf_ScalarString(NA_STRING));
      continue;
    }
    if (g < 0) {
      // The element's pattern has no such group: NA for each match.
      SEXP v = PROTECT(Rf_allocVector(STRSXP, e->count));
      for (int m = 0; m < e->count; m++) SET_STRING_ELT(v, m, NA_STRING);
      SET_VECTOR_ELT(out, i, v);
      UNPROTECT(1);
      continue;
    }
    SEXP v = PROTECT(Rf_allocVector(STRSXP, e->count));
    for (int m = 0; m < e->count; m++) {
      const PCRE2_SIZE *ov = e->ov + (size_t) m * job->width * 2;
      SET_STRING_ELT(v, m, make_string(&call->subjects[i], ov[2 * g],
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
      const PCRE2_SIZE *ov = e->ov + (size_t) m * job->width * 2;
      if (job->all) {
        element[r] = (int) i + 1;
        match[r] = m + 1;
      }
      for (int j = 0; j < entries; j++) {
        int g = j + first;
        SEXP col = VECTOR_ELT(out, cols[j] - 1 + lead);
        SET_STRING_ELT(col, r, make_string(&call->subjects[i], ov[2 * g],
                                           ov[2 * g + 1], utf));
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
      const PCRE2_SIZE *ov = e->ov + (size_t) m * job->width * 2;
      PCRE2_SIZE from = last, to = ov[0] > last ? ov[0] : last;
      SET_STRING_ELT(v, at++, make_string(s, from, to, utf));
      if (job->keep_groups) {
        for (uint32_t g = 1; g <= groups; g++) {
          SET_STRING_ELT(v, at++, make_string(s, ov[2 * g], ov[2 * g + 1], utf));
        }
      }
      if (ov[1] > last) last = ov[1];
    }
    SET_STRING_ELT(v, at, make_string(s, last, s->len, utf));
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
  job->el = calloc(n, sizeof(element_caps));
  if (job->el == NULL) Rf_error("out of memory allocating match buffers");
  scan(job, limit, status);
  SEXP err = PROTECT(zuregex_status_error(call, status));
  SEXP value = R_NilValue;
  if (Rf_isNull(err)) {
    value = R_ExecWithCleanup(build, job, free_caps, job);
  } else {
    free_caps(job);
  }
  PROTECT(value);
  SEXP ans = zuregex_result(call, status, value, err);
  UNPROTECT(2);
  return ans;
}

// group: per pattern table entry, the group to extract (0 is the whole
// match), or -1 where that pattern has no such group.
SEXP zuregex_extract_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                       SEXP group, SEXP all, SEXP n_max) {
  zuregex_call call;
  zuregex_collect(x, Rf_asLogical(bytes), table, index, limits, &call);
  capture_job job;
  memset(&job, 0, sizeof(job));
  job.call = &call;
  job.group = INTEGER(group);
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
  job.keep_groups = Rf_asLogical(keep_groups);
  return run(&job, Rf_asReal(n_max), build_split);
}

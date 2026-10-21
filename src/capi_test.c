// Internal .Call entry points that use the C API exactly as a consumer
// does: through <zuregex-r.h>, so through R_GetCCallable() and the
// registered table. tests/testthat/test-capi.R and the PCRE2 testdata
// harness call them.

#include <stdlib.h>
#include <string.h>

#include "zuregex.h"
#include "../inst/include/zuregex-r.h"

// A copy of `len` bytes followed by 64 zero bytes, so JIT code's reads past
// the end stay initialised under valgrind (see zr_match() in zuregex.h).
static const char *padded(const char *s, size_t len) {
  char *copy = R_alloc(len + 64, 1);
  memcpy(copy, s, len);
  memset(copy + len, 0, 64);
  return copy;
}

static zr_pattern *compile_or_error(SEXP pattern, SEXP flags, SEXP dialect) {
  // A "bytes" string is passed as it is: the PCRE2 testdata corpus has
  // patterns that are not UTF-8.
  SEXP s = STRING_ELT(pattern, 0);
  const char *pat = Rf_getCharCE(s) == CE_BYTES ? CHAR(s) : Rf_translateCharUTF8(s);
  size_t len = Rf_getCharCE(s) == CE_BYTES ? (size_t) LENGTH(s) : strlen(pat);
  char err[256];
  zr_pattern *p = zr_compile(pat, len, (uint32_t) Rf_asReal(flags),
                             Rf_asInteger(dialect), err, sizeof(err));
  if (p == NULL) Rf_error("zr_compile: %s", err);
  return p;
}

// For each subject, the first match's offsets as an integer matrix with a
// row per group (start, end; -1 for a group that did not take part), or
// the zr_match() status as an integer when there is no match.
SEXP zuregex_capi_match_c(SEXP pattern, SEXP flags, SEXP dialect,
                          SEXP subjects, SEXP options) {
  zr_pattern *p = compile_or_error(pattern, flags, dialect);
  zr_match_data *md = zr_match_data_create(p);
  if (md == NULL) {
    zr_free(p);
    Rf_error("zr_match_data_create failed");
  }
  int groups = zr_group_count(p);
  R_xlen_t n = XLENGTH(subjects);
  SEXP out = PROTECT(Rf_allocVector(VECSXP, n));
  for (R_xlen_t i = 0; i < n; i++) {
    SEXP s = STRING_ELT(subjects, i);
    size_t len = (size_t) LENGTH(s);
    const char *subj = padded(CHAR(s), len);
    int rc = zr_match(p, subj, len, 0, (uint32_t) Rf_asInteger(options), md);
    if (rc < 0) {
      SET_VECTOR_ELT(out, i, Rf_ScalarInteger(rc));
      continue;
    }
    SEXP m = Rf_allocMatrix(INTSXP, groups + 1, 2);
    SET_VECTOR_ELT(out, i, m);
    int *v = INTEGER(m);
    for (int g = 0; g <= groups; g++) {
      size_t a, b;
      if (zr_offsets(md, g, &a, &b) == ZR_OK) {
        v[g] = (int) a;
        v[g + groups + 1] = (int) b;
      } else {
        v[g] = v[g + groups + 1] = -1;
      }
    }
  }
  zr_match_data_free(md);
  zr_free(p);
  UNPROTECT(1);
  return out;
}

// zr_substitute() on one subject; the result, or the status as an integer.
SEXP zuregex_capi_substitute_c(SEXP pattern, SEXP flags, SEXP dialect,
                               SEXP subject, SEXP tmpl, SEXP options,
                               SEXP bufsize) {
  zr_pattern *p = compile_or_error(pattern, flags, dialect);
  const char *subj0 = Rf_translateCharUTF8(STRING_ELT(subject, 0));
  const char *subj = padded(subj0, strlen(subj0));
  const char *t = Rf_translateCharUTF8(STRING_ELT(tmpl, 0));
  size_t size = (size_t) Rf_asReal(bufsize);
  char *buf = R_alloc(size > 0 ? size : 1, 1);
  size_t outlen = size;
  int rc = zr_substitute(p, subj, strlen(subj), t, strlen(t),
                         (uint32_t) Rf_asInteger(options), NULL, buf, &outlen);
  zr_free(p);
  const char *names[] = {"rc", "out", "outlen", ""};
  SEXP res = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(res, 0, Rf_ScalarInteger(rc));
  SET_VECTOR_ELT(res, 1, rc >= 0 ? Rf_ScalarString(Rf_mkCharLenCE(buf, (int) outlen, CE_UTF8))
                                 : Rf_ScalarString(NA_STRING));
  SET_VECTOR_ELT(res, 2, Rf_ScalarReal((double) outlen));
  UNPROTECT(1);
  return res;
}

// What the C API says about a pattern.
SEXP zuregex_capi_info_c(SEXP pattern, SEXP flags, SEXP dialect, SEXP name) {
  zr_pattern *p = compile_or_error(pattern, flags, dialect);
  int groups = zr_group_count(p);
  const char *names[] = {"version", "groups", "names", "jit", "number", ""};
  SEXP res = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(res, 0, Rf_mkString(zr_version()));
  SET_VECTOR_ELT(res, 1, Rf_ScalarInteger(groups));
  SEXP gn = Rf_allocVector(STRSXP, groups);
  SET_VECTOR_ELT(res, 2, gn);
  for (int g = 1; g <= groups; g++) {
    const char *nm = zr_group_name(p, g);
    SET_STRING_ELT(gn, g - 1, nm ? Rf_mkCharCE(nm, CE_UTF8) : NA_STRING);
  }
  SET_VECTOR_ELT(res, 3, Rf_ScalarLogical(zr_jit(p)));
  SET_VECTOR_ELT(res, 4, Rf_ScalarInteger(
    zr_group_number(p, Rf_translateCharUTF8(STRING_ELT(name, 0)))));
  zr_free(p);
  UNPROTECT(1);
  return res;
}

// A pathological match under limits set through zr_set_limits().
SEXP zuregex_capi_limit_c(SEXP pattern, SEXP subject, SEXP match_limit) {
  SEXP flags = PROTECT(Rf_ScalarReal(0));
  SEXP dialect = PROTECT(Rf_ScalarInteger(0));
  zr_pattern *p = compile_or_error(pattern, flags, dialect);
  UNPROTECT(2);
  zr_match_data *md = zr_match_data_create(p);
  zr_set_limits(md, (uint32_t) Rf_asReal(match_limit), 0, 0);
  const char *subj0 = CHAR(STRING_ELT(subject, 0));
  const char *subj = padded(subj0, strlen(subj0));
  int rc = zr_match(p, subj, strlen(subj0), 0, 0, md);
  zr_match_data_free(md);
  zr_free(p);
  return Rf_ScalarInteger(rc);
}

// The C API's edge cases, run in C and returned as a named list for
// test-capi.R to assert: argument errors, status codes, foreign match
// data, substitution with match data, and zr_strerror().
SEXP zuregex_capi_edges_c(void) {
  const char *names[] = {
    "unknown_flags", "bad_dialect", "null_pattern", "zero_terminated_groups",
    "offsets_bad_group", "offsets_unset", "foreign_md_rc", "notempty_atstart",
    "substitute_bad_option", "substitute_with_md", "substitute_limit",
    "depth_limit", "heap_limit", "jit_stack", "jit_stack_retry",
    "strerror_match_limit", "strerror_unknown", ""
  };
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  char err[128];
  int k = 0;

  SET_VECTOR_ELT(out, k++, Rf_ScalarLogical(
    zr_compile("a", 1, 0x80000000u, ZR_DIALECT_PCRE, err, sizeof(err)) == NULL));
  SET_VECTOR_ELT(out, k++, Rf_ScalarLogical(
    zr_compile("a", 1, 0, 7, err, sizeof(err)) == NULL));
  SET_VECTOR_ELT(out, k++, Rf_ScalarLogical(
    zr_compile(NULL, 3, 0, ZR_DIALECT_PCRE, err, sizeof(err)) == NULL));

  // SIZE_MAX, PCRE2_ZERO_TERMINATED, reads a NUL-terminated pattern.
  zr_pattern *zt = zr_compile("(a)(b)", (size_t) -1, 0, ZR_DIALECT_PCRE, err, sizeof(err));
  SET_VECTOR_ELT(out, k++, Rf_ScalarInteger(zt != NULL ? zr_group_count(zt) : -99));

  zr_pattern *p = zr_compile("(a)|(b)", 7, 0, ZR_DIALECT_PCRE, err, sizeof(err));
  zr_match_data *md = zr_match_data_create(p);
  const char *s = padded("b", 1);
  zr_match(p, s, 1, 0, 0, md);
  size_t a, b;
  SET_VECTOR_ELT(out, k++, Rf_ScalarInteger(zr_offsets(md, 9, &a, &b)));
  SET_VECTOR_ELT(out, k++, Rf_ScalarInteger(zr_offsets(md, 1, &a, &b)));

  // Match data made for a pattern with fewer groups: the pairs it has.
  zr_pattern *none = zr_compile("b", 1, 0, ZR_DIALECT_PCRE, err, sizeof(err));
  zr_match_data *small = zr_match_data_create(none);
  SET_VECTOR_ELT(out, k++, Rf_ScalarInteger(zr_match(p, s, 1, 0, 0, small)));
  zr_match_data_free(small);
  zr_free(none);

  zr_pattern *star = zr_compile("x*", 2, 0, ZR_DIALECT_PCRE, err, sizeof(err));
  zr_match_data *smd = zr_match_data_create(star);
  const char *ab = padded("ab", 2);
  SET_VECTOR_ELT(out, k++, Rf_ScalarInteger(
    zr_match(star, ab, 2, 0, ZR_NOTEMPTY_ATSTART, smd)));
  zr_match_data_free(smd);
  zr_free(star);

  char buf[64];
  size_t size = sizeof(buf);
  SET_VECTOR_ELT(out, k++, Rf_ScalarInteger(
    zr_substitute(p, s, 1, "x", 1, 0x80u, NULL, buf, &size)));
  size = sizeof(buf);
  int rc = zr_substitute(p, s, 1, "<$0>", 4, 0, md, buf, &size);
  SET_VECTOR_ELT(out, k++, rc >= 0 ? Rf_mkString(buf) : Rf_ScalarInteger(rc));

  // Limits during a substitution, through the match data.
  zr_pattern *evil = zr_compile("^(a+)+$", 7, 0, ZR_DIALECT_PCRE, err, sizeof(err));
  zr_match_data *emd = zr_match_data_create(evil);
  zr_set_limits(emd, 1000, 0, 0);
  const char *subj = padded("aaaaaaaaaaaaaaaaaaaaaaaaaaaa!", 29);
  size = sizeof(buf);
  SET_VECTOR_ELT(out, k++, Rf_ScalarInteger(
    zr_substitute(evil, subj, 29, "x", 1, 0, emd, buf, &size)));
  zr_match_data_free(emd);
  zr_free(evil);

  // Depth and heap limits bind the interpreter.
  zr_pattern *slow = zr_compile("^(a+)+$", 7, ZR_NO_JIT, ZR_DIALECT_PCRE, err, sizeof(err));
  zr_match_data *dmd = zr_match_data_create(slow);
  zr_set_limits(dmd, 0, 10, 0);
  SET_VECTOR_ELT(out, k++, Rf_ScalarInteger(zr_match(slow, subj, 29, 0, 0, dmd)));
  zr_match_data_free(dmd);
  zr_free(slow);
  const char *deep_pat = "^(?:(a)|b)*$";
  zr_pattern *deep = zr_compile(deep_pat, strlen(deep_pat), ZR_NO_JIT, ZR_DIALECT_PCRE, err, sizeof(err));
  zr_match_data *hmd = zr_match_data_create(deep);
  zr_set_limits(hmd, 0, 0, 1);
  size_t dlen = 200000;
  char *dsub = R_alloc(dlen + 64, 1);
  for (size_t i = 0; i < dlen; i++) dsub[i] = (i % 2) ? 'b' : 'a';
  memset(dsub + dlen, 0, 64);
  SET_VECTOR_ELT(out, k++, Rf_ScalarInteger(zr_match(deep, dsub, dlen, 0, 0, hmd)));
  zr_match_data_free(hmd);
  zr_free(deep);

  // A JIT stack overflow, and the retry in the interpreter.
  zr_pattern *jit = zr_compile(deep_pat, strlen(deep_pat), 0, ZR_DIALECT_PCRE, err, sizeof(err));
  zr_match_data *jmd = zr_match_data_create(jit);
  int jrc = zr_jit(jit) ? zr_match(jit, dsub, dlen, 0, 0, jmd) : NA_INTEGER;
  SET_VECTOR_ELT(out, k++, Rf_ScalarInteger(jrc));
  int rrc = zr_jit(jit) ? zr_match(jit, dsub, dlen, 0, ZR_NO_JIT_MATCH, jmd) : NA_INTEGER;
  SET_VECTOR_ELT(out, k++, Rf_ScalarInteger(rrc));
  zr_match_data_free(jmd);
  zr_free(jit);

  SET_VECTOR_ELT(out, k++, Rf_mkString(zr_strerror(ZR_ERROR_MATCH_LIMIT)));
  SET_VECTOR_ELT(out, k++, Rf_mkString(zr_strerror(-1000)));

  zr_match_data_free(md);
  zr_free(p);
  zr_free(zt);
  UNPROTECT(1);
  return out;
}

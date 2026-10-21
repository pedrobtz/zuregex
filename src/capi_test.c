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

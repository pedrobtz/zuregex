// A consumer of zuregex's C API: compiles, matches and substitutes with
// zr_*() only, never naming PCRE2.

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <string.h>

#include <zuregex-r.h>

static zr_pattern *compile(SEXP pattern) {
  const char *pat = Rf_translateCharUTF8(STRING_ELT(pattern, 0));
  char err[256];
  zr_pattern *p = zr_compile(pat, strlen(pat), 0, ZR_DIALECT_PCRE, err,
                             sizeof(err));
  if (p == NULL) Rf_error("%s", err);
  return p;
}

// One-based, inclusive start and end of the first match of each subject,
// or NA: the R convention, converted at this boundary.
SEXP link_match_c(SEXP pattern, SEXP x) {
  zr_pattern *p = compile(pattern);
  zr_match_data *md = zr_match_data_create(p);
  R_xlen_t n = XLENGTH(x);
  SEXP out = PROTECT(Rf_allocMatrix(INTSXP, (int) n, 2));
  int *v = INTEGER(out);
  for (R_xlen_t i = 0; i < n; i++) {
    const char *s = Rf_translateCharUTF8(STRING_ELT(x, i));
    size_t a, b;
    if (zr_match(p, s, strlen(s), 0, 0, md) > 0 &&
        zr_offsets(md, 0, &a, &b) == ZR_OK) {
      v[i] = (int) a + 1;
      v[i + n] = (int) b;
    } else {
      v[i] = v[i + n] = NA_INTEGER;
    }
  }
  zr_match_data_free(md);
  zr_free(p);
  UNPROTECT(1);
  return out;
}

SEXP link_replace_c(SEXP pattern, SEXP x, SEXP tmpl) {
  zr_pattern *p = compile(pattern);
  const char *s = Rf_translateCharUTF8(STRING_ELT(x, 0));
  const char *t = Rf_translateCharUTF8(STRING_ELT(tmpl, 0));
  size_t size = 8;  // small on purpose: exercises the retry protocol
  char *buf = R_alloc(size, 1);
  int rc = zr_substitute(p, s, strlen(s), t, strlen(t), ZR_SUBSTITUTE_GLOBAL,
                         NULL, buf, &size);
  if (rc == ZR_ERROR_NOMEMORY) {
    buf = R_alloc(size, 1);
    rc = zr_substitute(p, s, strlen(s), t, strlen(t), ZR_SUBSTITUTE_GLOBAL,
                       NULL, buf, &size);
  }
  zr_free(p);
  if (rc < 0) Rf_error("zr_substitute: %s", zr_strerror(rc));
  return Rf_ScalarString(Rf_mkCharLenCE(buf, (int) size, CE_UTF8));
}

SEXP link_groups_c(SEXP pattern) {
  zr_pattern *p = compile(pattern);
  int n = zr_group_count(p);
  SEXP out = PROTECT(Rf_allocVector(STRSXP, n));
  for (int g = 1; g <= n; g++) {
    const char *name = zr_group_name(p, g);
    SET_STRING_ELT(out, g - 1, name ? Rf_mkCharCE(name, CE_UTF8) : R_BlankString);
  }
  zr_free(p);
  UNPROTECT(1);
  return out;
}

SEXP link_version_c(void) {
  return Rf_mkString(zr_version());
}

static const R_CallMethodDef methods[] = {
  {"link_match_c", (DL_FUNC) &link_match_c, 2},
  {"link_replace_c", (DL_FUNC) &link_replace_c, 3},
  {"link_groups_c", (DL_FUNC) &link_groups_c, 1},
  {"link_version_c", (DL_FUNC) &link_version_c, 0},
  {NULL, NULL, 0}
};

void R_init_zuregexlink(DllInfo *dll) {
  R_registerRoutines(dll, NULL, methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
}

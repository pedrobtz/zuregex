// R entry points for re_compile(), re_info() and the cache.
//
// An `re` object is a list of external pointers, one per pattern, each
// holding one reference to a zuregex_pattern. An NA pattern is NULL in the
// list. An external pointer read back from saveRDS() has a NULL address;
// re_valid_c() lets the R side find and recompile those.

#include <string.h>

#include "zuregex.h"
#include "pattern.h"

static void finalize_pattern(SEXP ptr) {
  zuregex_pattern *p = R_ExternalPtrAddr(ptr);
  if (p != NULL) {
    R_ClearExternalPtr(ptr);
    zuregex_pattern_release(p);
  }
}

// An error description for the R side to raise: list(kind, element,
// offset, message). `offset` is one-based and in characters.
static SEXP compile_error(const char *kind, int element, int offset,
                          const char *message) {
  const char *names[] = {"kind", "element", "offset", "message", ""};
  SEXP err = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(err, 0, Rf_mkString(kind));
  SET_VECTOR_ELT(err, 1, Rf_ScalarInteger(element));
  SET_VECTOR_ELT(err, 2, Rf_ScalarInteger(offset));
  SET_VECTOR_ELT(err, 3, Rf_mkString(message));  // PCRE2's are ASCII
  UNPROTECT(1);
  return err;
}

static SEXP result(SEXP value, SEXP error) {
  const char *names[] = {"value", "error", ""};
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(out, 0, value);
  SET_VECTOR_ELT(out, 1, error);
  UNPROTECT(1);
  return out;
}

static int byte_to_char_offset(const char *s, size_t bytes) {
  int chars = 0;
  for (size_t i = 0; i < bytes; i++) {
    if (((unsigned char) s[i] & 0xC0) != 0x80) chars++;
  }
  return chars;
}

// pattern: UTF-8 character vector; flags: one string; dialect: 0 or 1;
// utf: compile for UTF-8 (TRUE) or bytes (FALSE); use_cache: go through
// the cache.
// Returns list(value = <list of external pointers>, error = NULL), or
// list(value = NULL, error = <description>) for the first failure.
SEXP zuregex_compile_c(SEXP pattern, SEXP flags, SEXP dialect, SEXP literal,
                       SEXP jit, SEXP utf, SEXP use_cache) {
  zuregex_key key;
  memset(&key, 0, sizeof(key));
  key.dialect = Rf_asInteger(dialect);
  key.literal = Rf_asLogical(literal);
  key.jit = Rf_asLogical(jit);
  key.utf = Rf_asLogical(utf);
  int cached = Rf_asLogical(use_cache);

  const char *f = Rf_translateCharUTF8(STRING_ELT(flags, 0));
  int bad = zuregex_parse_flags(f, key.literal, &key.options, &key.extra);
  if (bad) {
    SEXP err = PROTECT(compile_error("flags", 1, bad, ""));
    SEXP res = result(R_NilValue, err);
    UNPROTECT(1);
    return res;
  }

  R_xlen_t n = XLENGTH(pattern);
  SEXP out = PROTECT(Rf_allocVector(VECSXP, n));
  for (R_xlen_t i = 0; i < n; i++) {
    SEXP s = STRING_ELT(pattern, i);
    if (s == NA_STRING) continue;
    // The external pointer exists before the pattern does, so an
    // allocation error here cannot leak a reference.
    SEXP ptr = PROTECT(R_MakeExternalPtr(NULL, R_NilValue, R_NilValue));
    R_RegisterCFinalizerEx(ptr, finalize_pattern, TRUE);
    key.pattern = CHAR(s);
    key.length = (size_t) LENGTH(s);
    int errcode;
    size_t erroffset;
    zuregex_pattern *p = zuregex_cache_get(&key, cached, &errcode, &erroffset);
    if (p == NULL) {
      PCRE2_UCHAR msg[256];
      if (pcre2_get_error_message(errcode, msg, sizeof(msg)) < 0) {
        strcpy((char *) msg, "unknown error");
      }
      int offset = byte_to_char_offset(key.pattern, erroffset) + 1;
      SEXP err = PROTECT(compile_error("compile", (int) i + 1, offset,
                                       (const char *) msg));
      SEXP res = result(R_NilValue, err);
      UNPROTECT(3);
      return res;
    }
    R_SetExternalPtrAddr(ptr, p);
    SET_VECTOR_ELT(out, i, ptr);
    UNPROTECT(1);
  }
  SEXP res = result(out, R_NilValue);
  UNPROTECT(1);
  return res;
}

static zuregex_pattern *pattern_at(SEXP re, R_xlen_t i) {
  SEXP ptr = VECTOR_ELT(re, i);
  if (TYPEOF(ptr) != EXTPTRSXP) return NULL;
  return R_ExternalPtrAddr(ptr);
}

// TRUE where an element holds a live pattern; FALSE for NA patterns and
// for pointers that did not survive serialization.
SEXP zuregex_re_valid_c(SEXP re) {
  R_xlen_t n = XLENGTH(re);
  SEXP out = PROTECT(Rf_allocVector(LGLSXP, n));
  for (R_xlen_t i = 0; i < n; i++) {
    LOGICAL(out)[i] = pattern_at(re, i) != NULL;
  }
  UNPROTECT(1);
  return out;
}

static SEXP group_names(const pcre2_code *code, uint32_t groups) {
  SEXP names = PROTECT(Rf_allocVector(STRSXP, groups));
  for (uint32_t g = 0; g < groups; g++) {
    SET_STRING_ELT(names, g, R_BlankString);
  }
  uint32_t count = 0, entry_size = 0;
  PCRE2_SPTR table = NULL;
  pcre2_pattern_info(code, PCRE2_INFO_NAMECOUNT, &count);
  pcre2_pattern_info(code, PCRE2_INFO_NAMEENTRYSIZE, &entry_size);
  pcre2_pattern_info(code, PCRE2_INFO_NAMETABLE, &table);
  for (uint32_t k = 0; k < count; k++) {
    PCRE2_SPTR entry = table + (size_t) k * entry_size;
    uint32_t number = ((uint32_t) entry[0] << 8) | entry[1];
    if (number >= 1 && number <= groups) {
      SET_STRING_ELT(names, number - 1,
                     Rf_mkCharCE((const char *) entry + 2, CE_UTF8));
    }
  }
  UNPROTECT(1);
  return names;
}

// Columns of re_info(), computed from PCRE2's own record of each pattern.
SEXP zuregex_re_info_c(SEXP re) {
  R_xlen_t n = XLENGTH(re);
  const char *names[] = {"pattern", "flags", "dialect", "literal", "groups",
                         "group_names", "jit", "min_length", "backrefs", ""};
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  SEXP pattern = PROTECT(Rf_allocVector(STRSXP, n));
  SEXP flags = PROTECT(Rf_allocVector(STRSXP, n));
  SEXP dialect = PROTECT(Rf_allocVector(STRSXP, n));
  SEXP literal = PROTECT(Rf_allocVector(LGLSXP, n));
  SEXP groups = PROTECT(Rf_allocVector(INTSXP, n));
  SEXP gnames = PROTECT(Rf_allocVector(VECSXP, n));
  SEXP jit = PROTECT(Rf_allocVector(LGLSXP, n));
  SEXP minlen = PROTECT(Rf_allocVector(INTSXP, n));
  SEXP backrefs = PROTECT(Rf_allocVector(LGLSXP, n));
  for (R_xlen_t i = 0; i < n; i++) {
    zuregex_pattern *p = pattern_at(re, i);
    if (p == NULL) {
      SET_STRING_ELT(pattern, i, NA_STRING);
      SET_STRING_ELT(flags, i, NA_STRING);
      SET_STRING_ELT(dialect, i, NA_STRING);
      LOGICAL(literal)[i] = NA_LOGICAL;
      INTEGER(groups)[i] = NA_INTEGER;
      SET_VECTOR_ELT(gnames, i, Rf_ScalarString(NA_STRING));
      LOGICAL(jit)[i] = NA_LOGICAL;
      INTEGER(minlen)[i] = NA_INTEGER;
      LOGICAL(backrefs)[i] = NA_LOGICAL;
      continue;
    }
    uint32_t options = 0, extra = 0, capture = 0, min = 0, backmax = 0;
    pcre2_pattern_info(p->code, PCRE2_INFO_ARGOPTIONS, &options);
    pcre2_pattern_info(p->code, PCRE2_INFO_EXTRAOPTIONS, &extra);
    pcre2_pattern_info(p->code, PCRE2_INFO_CAPTURECOUNT, &capture);
    pcre2_pattern_info(p->code, PCRE2_INFO_MINLENGTH, &min);
    pcre2_pattern_info(p->code, PCRE2_INFO_BACKREFMAX, &backmax);
    char buf[32];
    zuregex_format_flags(options, extra, buf);
    SET_STRING_ELT(pattern, i,
                   Rf_mkCharLenCE(p->pattern, (int) p->key.length, CE_UTF8));
    SET_STRING_ELT(flags, i, Rf_mkChar(buf));
    SET_STRING_ELT(dialect, i,
                   Rf_mkChar(p->key.dialect == ZUREGEX_DIALECT_JS ? "js" : "pcre"));
    LOGICAL(literal)[i] = p->key.literal;
    INTEGER(groups)[i] = (int) capture;
    SET_VECTOR_ELT(gnames, i, group_names(p->code, capture));
    LOGICAL(jit)[i] = p->jit_in_use;
    INTEGER(minlen)[i] = (int) min;
    LOGICAL(backrefs)[i] = backmax > 0;
  }
  SEXP cols[] = {pattern, flags, dialect, literal, groups, gnames, jit,
                 minlen, backrefs};
  for (int k = 0; k < 9; k++) SET_VECTOR_ELT(out, k, cols[k]);
  UNPROTECT(10);
  return out;
}

SEXP zuregex_cache_size_c(SEXP n) {
  if (Rf_isNull(n)) return Rf_ScalarInteger(zuregex_cache_capacity());
  return Rf_ScalarInteger(zuregex_cache_set_capacity(Rf_asInteger(n)));
}

SEXP zuregex_cache_clear_c(void) {
  return Rf_ScalarInteger(zuregex_cache_clear());
}

SEXP zuregex_cache_stats_c(void) {
  zuregex_cache_stats s = zuregex_cache_get_stats();
  const char *names[] = {"size", "capacity", "hits", "misses", "evictions", ""};
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(out, 0, Rf_ScalarInteger(s.size));
  SET_VECTOR_ELT(out, 1, Rf_ScalarInteger(s.capacity));
  SET_VECTOR_ELT(out, 2, Rf_ScalarReal(s.hits));
  SET_VECTOR_ELT(out, 3, Rf_ScalarReal(s.misses));
  SET_VECTOR_ELT(out, 4, Rf_ScalarReal(s.evictions));
  UNPROTECT(1);
  return out;
}

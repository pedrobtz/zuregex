#ifndef ZUREGEX_H
#define ZUREGEX_H

#define R_NO_REMAP
#include <Rinternals.h>

SEXP zuregex_info_c(void);
SEXP zuregex_compile_c(SEXP pattern, SEXP flags, SEXP dialect, SEXP literal,
                       SEXP jit, SEXP utf, SEXP use_cache);
SEXP zuregex_re_valid_c(SEXP re);
SEXP zuregex_re_info_c(SEXP re);
SEXP zuregex_cache_size_c(SEXP n);
SEXP zuregex_cache_clear_c(void);
SEXP zuregex_cache_stats_c(void);
SEXP zuregex_detect_c(SEXP x, SEXP bytes, SEXP table, SEXP index,
                      SEXP anchor, SEXP negate);
SEXP zuregex_count_c(SEXP x, SEXP bytes, SEXP table, SEXP index);

#endif

#ifndef ZUREGEX_INTERNAL_H
#define ZUREGEX_INTERNAL_H

#define R_NO_REMAP
#include <Rinternals.h>

SEXP zuregex_info_c(void);
SEXP zuregex_threads_c(SEXP n);
SEXP zuregex_openmp_c(void);
SEXP zuregex_cores_c(void);
SEXP zuregex_serial_bytes_c(SEXP n);
SEXP zuregex_capi_match_c(SEXP pattern, SEXP flags, SEXP dialect,
                          SEXP subjects, SEXP options, SEXP start);
SEXP zuregex_capi_substitute_c(SEXP pattern, SEXP flags, SEXP dialect,
                               SEXP subject, SEXP tmpl, SEXP options,
                               SEXP bufsize);
SEXP zuregex_capi_info_c(SEXP pattern, SEXP flags, SEXP dialect, SEXP name);
SEXP zuregex_capi_limit_c(SEXP pattern, SEXP subject, SEXP match_limit);
SEXP zuregex_capi_edges_c(void);
SEXP zuregex_compile_c(SEXP pattern, SEXP flags, SEXP dialect, SEXP literal,
                       SEXP jit, SEXP utf, SEXP use_cache);
// The description of a compile error in the one pattern of a call, as
// zuregex_compile_c() describes them; erroffset is in bytes.
SEXP zuregex_compile_error_for(const char *pattern, int errcode,
                               size_t erroffset);
// A flags error, the first bad letter at one-based `offset`.
SEXP zuregex_flags_error_for(int offset);
SEXP zuregex_prepare_c(SEXP x, SEXP pattern, SEXP flags, SEXP literal);
SEXP zuregex_re_valid_c(SEXP re);
SEXP zuregex_re_info_c(SEXP re);
SEXP zuregex_cache_size_c(SEXP n);
SEXP zuregex_cache_clear_c(void);
SEXP zuregex_cache_stats_c(void);
SEXP zuregex_detect_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                      SEXP anchor, SEXP negate);
SEXP zuregex_count_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits);
SEXP zuregex_has_bytes_c(SEXP x);
SEXP zuregex_locate_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                      SEXP char_offsets);
SEXP zuregex_locate_all_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                          SEXP n_max, SEXP overlap, SEXP char_offsets);
SEXP zuregex_extract_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                       SEXP group, SEXP all, SEXP n_max);
SEXP zuregex_match_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                     SEXP colmap, SEXP ncol, SEXP all, SEXP n_max,
                     SEXP with_zero);
SEXP zuregex_replace_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                       SEXP repl, SEXP mode, SEXP literal, SEXP n_max,
                       SEXP expand_only, SEXP first);
SEXP zuregex_split_c(SEXP x, SEXP bytes, SEXP table, SEXP index, SEXP limits,
                     SEXP n_max, SEXP keep_groups);

#endif

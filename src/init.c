#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

#include "zuregex.h"

static const R_CallMethodDef call_methods[] = {
  {"zuregex_info_c", (DL_FUNC) &zuregex_info_c, 0},
  {"zuregex_compile_c", (DL_FUNC) &zuregex_compile_c, 7},
  {"zuregex_re_valid_c", (DL_FUNC) &zuregex_re_valid_c, 1},
  {"zuregex_re_info_c", (DL_FUNC) &zuregex_re_info_c, 1},
  {"zuregex_cache_size_c", (DL_FUNC) &zuregex_cache_size_c, 1},
  {"zuregex_cache_clear_c", (DL_FUNC) &zuregex_cache_clear_c, 0},
  {"zuregex_cache_stats_c", (DL_FUNC) &zuregex_cache_stats_c, 0},
  {"zuregex_detect_c", (DL_FUNC) &zuregex_detect_c, 7},
  {"zuregex_count_c", (DL_FUNC) &zuregex_count_c, 5},
  {"zuregex_locate_c", (DL_FUNC) &zuregex_locate_c, 6},
  {"zuregex_locate_all_c", (DL_FUNC) &zuregex_locate_all_c, 8},
  {"zuregex_extract_c", (DL_FUNC) &zuregex_extract_c, 8},
  {"zuregex_match_c", (DL_FUNC) &zuregex_match_c, 10},
  {"zuregex_replace_c", (DL_FUNC) &zuregex_replace_c, 11},
  {"zuregex_split_c", (DL_FUNC) &zuregex_split_c, 7},
  {NULL, NULL, 0}
};

// The one exported symbol. Everything else, PCRE2 included, is compiled
// with $(C_VISIBILITY) and stays hidden (design section 4).
void attribute_visible R_init_zuregex(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}

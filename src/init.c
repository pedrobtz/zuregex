#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

#include "zuregex.h"
#include "capi.h"
#include "../inst/include/zuregex-r.h"

static const R_CallMethodDef call_methods[] = {
  {"zuregex_info_c", (DL_FUNC) &zuregex_info_c, 0},
  {"zuregex_threads_c", (DL_FUNC) &zuregex_threads_c, 1},
  {"zuregex_openmp_c", (DL_FUNC) &zuregex_openmp_c, 0},
  {"zuregex_cores_c", (DL_FUNC) &zuregex_cores_c, 0},
  {"zuregex_serial_bytes_c", (DL_FUNC) &zuregex_serial_bytes_c, 1},
  {"zuregex_capi_match_c", (DL_FUNC) &zuregex_capi_match_c, 5},
  {"zuregex_capi_substitute_c", (DL_FUNC) &zuregex_capi_substitute_c, 7},
  {"zuregex_capi_info_c", (DL_FUNC) &zuregex_capi_info_c, 4},
  {"zuregex_capi_limit_c", (DL_FUNC) &zuregex_capi_limit_c, 3},
  {"zuregex_capi_edges_c", (DL_FUNC) &zuregex_capi_edges_c, 0},
  {"zuregex_compile_c", (DL_FUNC) &zuregex_compile_c, 7},
  {"zuregex_prepare_c", (DL_FUNC) &zuregex_prepare_c, 4},
  {"zuregex_re_valid_c", (DL_FUNC) &zuregex_re_valid_c, 1},
  {"zuregex_re_info_c", (DL_FUNC) &zuregex_re_info_c, 1},
  {"zuregex_cache_size_c", (DL_FUNC) &zuregex_cache_size_c, 1},
  {"zuregex_cache_clear_c", (DL_FUNC) &zuregex_cache_clear_c, 0},
  {"zuregex_cache_stats_c", (DL_FUNC) &zuregex_cache_stats_c, 0},
  {"zuregex_detect_c", (DL_FUNC) &zuregex_detect_c, 7},
  {"zuregex_count_c", (DL_FUNC) &zuregex_count_c, 5},
  {"zuregex_has_bytes_c", (DL_FUNC) &zuregex_has_bytes_c, 1},
  {"zuregex_locate_c", (DL_FUNC) &zuregex_locate_c, 6},
  {"zuregex_locate_all_c", (DL_FUNC) &zuregex_locate_all_c, 8},
  {"zuregex_extract_c", (DL_FUNC) &zuregex_extract_c, 8},
  {"zuregex_match_c", (DL_FUNC) &zuregex_match_c, 10},
  {"zuregex_replace_c", (DL_FUNC) &zuregex_replace_c, 11},
  {"zuregex_split_c", (DL_FUNC) &zuregex_split_c, 7},
  {NULL, NULL, 0}
};

// The C API's function table (inst/include/zuregex-r.h), registered for
// consumers' R_GetCCallable("zuregex", "zuregex_api_v1").
static const zuregex_api_v1 api_v1 = {
  ZUREGEX_API_VERSION,
  sizeof(zuregex_api_v1),
  zuregex_capi_version,
  zuregex_capi_compile,
  zuregex_capi_free,
  zuregex_capi_group_count,
  zuregex_capi_group_number,
  zuregex_capi_group_name,
  zuregex_capi_jit,
  zuregex_capi_match_data_create,
  zuregex_capi_match_data_free,
  zuregex_capi_set_limits,
  zuregex_capi_match,
  zuregex_capi_offsets,
  zuregex_capi_substitute,
  zuregex_capi_strerror,
};

static const zuregex_api_v1 *get_api_v1(void) {
  return &api_v1;
}

// The one exported symbol. Everything else, PCRE2 included, is compiled
// with $(C_VISIBILITY) and stays hidden (design section 4).
void attribute_visible R_init_zuregex(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_RegisterCCallable("zuregex", "zuregex_api_v1", (DL_FUNC) get_api_v1);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}

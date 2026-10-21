#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

#include "zuregex.h"

static const R_CallMethodDef call_methods[] = {
  {"zuregex_info_c", (DL_FUNC) &zuregex_info_c, 0},
  {NULL, NULL, 0}
};

// The one exported symbol. Everything else, PCRE2 included, is compiled
// with $(C_VISIBILITY) and stays hidden (design section 4).
void attribute_visible R_init_zuregex(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}

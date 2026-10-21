#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

// No native routines yet; each stage adds its entries here.
static const R_CallMethodDef call_methods[] = {
  {NULL, NULL, 0}
};

void R_init_zuregex(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}

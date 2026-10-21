// re_threads(): the package's thread cap, as zurand's rng_threads() has it
// (design D5). It applies per loop through num_threads(), so it governs only
// zuregex's own matching, not other OpenMP code in the process.

#include "zuregex.h"
#include "match.h"
#include "omp.h"

// 0 means no cap: omp_get_max_threads(), which honours OMP_NUM_THREADS and
// OMP_THREAD_LIMIT.
static int thread_cap = 0;

// The serial threshold, in total subject bytes. Settable internally so the
// tests and the measurement behind ZUREGEX_SERIAL_BYTES can run the
// parallel path on small inputs.
static double serial_bytes = ZUREGEX_SERIAL_BYTES;

static int max_threads(void) {
#ifdef ZUREGEX_OPENMP
  int max = omp_get_max_threads();
  return (thread_cap > 0 && thread_cap < max) ? thread_cap : max;
#else
  return 1;
#endif
}

int zuregex_threads_for(const zuregex_call *call) {
  if (call->n < 2 || call->total_bytes < serial_bytes) return 1;
  return max_threads();
}

// NULL queries the effective maximum. Otherwise sets the cap (0 removes it)
// and returns the previous cap, 0 for none, so that
// old <- re_threads(1); re_threads(old) restores it exactly.
SEXP zuregex_threads_c(SEXP n) {
  if (Rf_isNull(n)) return Rf_ScalarInteger(max_threads());
  int previous = thread_cap;
  thread_cap = Rf_asInteger(n);
  return Rf_ScalarInteger(previous);
}

SEXP zuregex_openmp_c(void) {
#ifdef ZUREGEX_OPENMP
  return Rf_ScalarLogical(1);
#else
  return Rf_ScalarLogical(0);
#endif
}

// Sets the serial threshold and returns the previous one; NULL queries.
SEXP zuregex_serial_bytes_c(SEXP n) {
  double previous = serial_bytes;
  if (!Rf_isNull(n)) serial_bytes = Rf_asReal(n);
  return Rf_ScalarReal(previous);
}

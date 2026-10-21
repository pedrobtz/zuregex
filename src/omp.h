#ifndef ZUREGEX_OMP_H
#define ZUREGEX_OMP_H

// OpenMP for phase 2 (design section 6.6), gated on one macro as zurand
// gates it. WRE's idiom is a bare #ifdef _OPENMP around <omp.h>, which
// assumes a compiler that defines _OPENMP also ships the header; the clang
// sanitizer containers define it without the header. There the build is
// serial instead of broken.
#ifdef __has_include
#  if __has_include(<omp.h>)
#    define ZUREGEX_HAVE_OMP_H 1
#  endif
#else
#  define ZUREGEX_HAVE_OMP_H 1
#endif

#if defined(_OPENMP) && defined(ZUREGEX_HAVE_OMP_H)
#  include <omp.h>
#  define ZUREGEX_OPENMP 1
#endif

// The phase-2 loop of every verb:
//
//   int nt = zuregex_threads_for(&call);
//   ZUREGEX_OMP_PARALLEL
//   {
//     ... per-thread state, such as match data ...
//     ZUREGEX_OMP_FOR
//     for (R_xlen_t i = 0; i < n; i++) { ... }
//   }
//
// The variable must be named nt. Without OpenMP the block runs once:
// ZUREGEX_OMP_PARALLEL only marks nt as used, and ZUREGEX_OMP_FOR is
// empty. Scheduling is dynamic: per-element patterns and subject lengths
// make elements cost different amounts.
#define ZUREGEX_PRAGMA(x) _Pragma(#x)
#ifdef ZUREGEX_OPENMP
#  define ZUREGEX_OMP_PARALLEL ZUREGEX_PRAGMA(omp parallel num_threads(nt) if(nt > 1))
#  define ZUREGEX_OMP_FOR ZUREGEX_PRAGMA(omp for schedule(dynamic, 64))
#else
#  define ZUREGEX_OMP_PARALLEL (void) nt;
#  define ZUREGEX_OMP_FOR
#endif

// Below this many subject bytes in a call, phase 2 runs on one thread:
// starting threads costs more than the matching. Measured in Stage 8 with
// the cheapest pattern, the worst case for threading: four threads first
// beat one at 16 KiB (see the roadmap).
#define ZUREGEX_SERIAL_BYTES ((double) 16384)

#endif

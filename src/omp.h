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
//     ZUREGEX_FOR_EACH(i, n) { ... }
//   }
//
// The variable must be named nt, and a function holds at most one such
// block: ZUREGEX_OMP_PARALLEL declares the block's chunk counter. Without
// OpenMP the block runs once and the loop visits every element in order.
//
// Scheduling is dynamic, because per-element patterns and subject lengths
// make elements cost different amounts. Each thread claims the next chunk
// of ZUREGEX_CHUNK elements with an atomic add on the shared counter. That
// is done here rather than with schedule(dynamic): clang from LLVM 19 on
// compiles schedule(dynamic) to a call to __kmpc_dispatch_deinit, which
// the older libomp R ships on macOS lacks, so the package would build and
// then fail to load (#72). The block's only runtime calls are the fork
// and omp_get_thread_num(), which every libomp has. The counter is
// unsigned int: a call has at most INT_MAX elements, so it cannot wrap,
// and a 32-bit atomic needs no libatomic on 32-bit builds.
#define ZUREGEX_CHUNK 64u
#define ZUREGEX_PRAGMA(x) _Pragma(#x)
#ifdef ZUREGEX_OPENMP
#  define ZUREGEX_OMP_PARALLEL                                               \
    unsigned int zuregex_next_chunk_ = 0;                                    \
    ZUREGEX_PRAGMA(omp parallel num_threads(nt) if(nt > 1))
#  define ZUREGEX_THREAD_NUM omp_get_thread_num()
#else
#  define ZUREGEX_OMP_PARALLEL                                               \
    unsigned int zuregex_next_chunk_ = 0;                                    \
    (void) nt;
#  define ZUREGEX_THREAD_NUM 0
#endif

#define ZUREGEX_FOR_EACH(i, n)                                               \
  for (R_xlen_t zuregex_lo_ = (R_xlen_t) __atomic_fetch_add(                 \
           &zuregex_next_chunk_, ZUREGEX_CHUNK, __ATOMIC_RELAXED);           \
       zuregex_lo_ < (n);                                                    \
       zuregex_lo_ = (R_xlen_t) __atomic_fetch_add(                          \
           &zuregex_next_chunk_, ZUREGEX_CHUNK, __ATOMIC_RELAXED))           \
    for (R_xlen_t i = zuregex_lo_,                                           \
                  zuregex_hi_ = zuregex_lo_ + (R_xlen_t) ZUREGEX_CHUNK < (n) \
                                  ? zuregex_lo_ + (R_xlen_t) ZUREGEX_CHUNK   \
                                  : (n);                                     \
         i < zuregex_hi_; i++)

// The thread's index inside ZUREGEX_OMP_PARALLEL, below nt: which of the
// call's per-thread arenas it writes.

// Below this many subject bytes in a call, phase 2 runs on one thread:
// starting threads costs more than the matching. Measured in Stage 8 with
// the cheapest pattern, the worst case for threading: four threads first
// beat one at 16 KiB (see the roadmap).
#define ZUREGEX_SERIAL_BYTES ((double) 16384)

#endif

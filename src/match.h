#ifndef ZUREGEX_MATCH_H
#define ZUREGEX_MATCH_H

// The three phases every verb shares (design section 4). Phase 1 runs on
// the main thread and turns R objects into plain C arrays; phase 2 reads
// only those arrays and writes only into buffers allocated before it, so
// it never touches the R API and Stage 8 can run it on several threads;
// phase 3 builds R results on the main thread.

#define R_NO_REMAP
#include <Rinternals.h>

#include "pattern.h"

// One subject. `ptr` stays valid for the whole call: it points into an R
// object the caller protects or into R_alloc() memory.
typedef struct {
  const char *ptr;
  size_t len;
  int na;
} zuregex_subject;

// Everything phase 2 needs, collected in phase 1.
typedef struct {
  R_xlen_t n;                  // number of subjects
  zuregex_subject *subjects;   // n of them
  zuregex_pattern **patterns;  // the call's distinct patterns
  int n_patterns;
  const int *index;            // per subject: 1-based pattern, NA_INTEGER for NA
  int index_len;               // 1 (one pattern for all) or n
  uint32_t max_ovector;        // pairs needed by the pattern with most groups
} zuregex_call;

// Phase 2 status per element.
typedef struct {
  int rc;         // 0, or the PCRE2 error code that stopped this element
  size_t offset;  // for UTF errors, the byte offset of the bad character
} zuregex_status;

void zuregex_collect(SEXP x, int bytes, SEXP table, SEXP index,
                     zuregex_call *call);

// The pattern for element i, or NULL for an NA pattern or subject.
zuregex_pattern *zuregex_pattern_for(const zuregex_call *call, R_xlen_t i);

// Raises the first element error in `status`, if any, as an R condition
// description for the R side: list(kind, element, rc, offset, message).
// Returns R_NilValue when every element succeeded.
SEXP zuregex_status_error(const zuregex_call *call,
                          const zuregex_status *status);

#endif

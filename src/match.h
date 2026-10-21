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

// One pcre2_match(). Returns 1 for a match, 0 for none, -1 for an error
// recorded in *st.
int zuregex_match_once(const zuregex_pattern *p, const zuregex_subject *s,
                       size_t start, uint32_t options, pcre2_match_data *md,
                       zuregex_status *st);

// Where the next search starts after a match, by the pattern's dialect:
// PCRE2's rule (pcre2_next_match()) or JavaScript's, which steps one
// character past an empty match instead of retrying it as non-empty. With
// overlap, the next search starts one character after this match's start.
// Returns 0 when there is nothing left to search.
int zuregex_next_start(const zuregex_pattern *p, const zuregex_subject *s,
                       pcre2_match_data *md, int overlap, size_t *start,
                       uint32_t *options);

// Characters in s[0, bytes), counting UTF-8 lead bytes; in bytes mode a
// byte is a character.
size_t zuregex_chars(const char *s, size_t bytes, int utf);

// Raises the first element error in `status`, if any, as an R condition
// description for the R side: list(kind, element, rc, offset, message).
// Returns R_NilValue when every element succeeded.
SEXP zuregex_status_error(const zuregex_call *call,
                          const zuregex_status *status);

// list(value, error), as every verb returns to R.
SEXP zuregex_result(SEXP value, SEXP error);

#endif

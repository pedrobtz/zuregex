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
  int ascii;  // R marks the string ASCII: valid UTF-8 without checking
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
  double total_bytes;          // of all subjects: decides serial or parallel
  pcre2_match_context *mctx;   // the call's limits; NULL for PCRE2's defaults
  int limit_na;                // on_limit = "na": a limited element is NA
} zuregex_call;

// Phase 2 status per element.
typedef struct {
  int rc;         // 0, or the PCRE2 error code that stopped this element
  int in_template;  // the error came from expanding a replacement template
  size_t offset;  // UTF errors: byte offset of the bad character;
                  // template errors: byte offset in the template
} zuregex_status;

// limits: a double vector of match, depth and heap limits (NA keeps
// PCRE2's default) and the on_limit mode (1 for "na").
void zuregex_collect(SEXP x, int bytes, SEXP table, SEXP index, SEXP limits,
                     zuregex_call *call);

// Threads for phase 2 of this call (threads.c): 1 below the serial
// threshold, otherwise the cap set by re_threads().
int zuregex_threads_for(const zuregex_call *call);

// The pattern for element i, or NULL for an NA pattern or subject.
zuregex_pattern *zuregex_pattern_for(const zuregex_call *call, R_xlen_t i);

// PCRE2's JIT code scans with wide loads that can read up to this many
// bytes past the end of the subject. That is safe within a page, but past an
// R string those bytes are uninitialised heap, which valgrind (and so
// CRAN's valgrind check) reports. Phase 2 therefore matches a copy of each
// subject followed by this many zero bytes.
#define ZUREGEX_PADDING 64

// A per-thread buffer for padded subjects, grown as needed; start it at
// {NULL, 0} and free it with free(buf.data).
typedef struct {
  char *data;
  size_t cap;
} zuregex_pad_buf;

// Copies *s into *buf followed by ZUREGEX_PADDING zero bytes and sets *out
// to the copy. Offsets into the copy equal offsets into the original.
// Returns 0 when memory ran out. No R API.
int zuregex_pad(const zuregex_subject *s, zuregex_pad_buf *buf,
                zuregex_subject *out);

// Per-thread output of phase 2. Each thread appends one element's results
// at a time, so they are contiguous; elements record which arena and the
// offset they start at, never a pointer, because growing an arena moves it.
// One growing buffer per thread replaces a malloc() per element.
typedef struct {
  char *data;
  size_t len, cap;
} zuregex_arena;

// nt empty arenas, or NULL when memory ran out. Called on the main thread.
zuregex_arena *zuregex_arenas_new(int nt);
void zuregex_arenas_free(zuregex_arena *arenas, int nt);

// Room for n more bytes after a->len. Returns 0 when memory ran out. Keeps
// data aligned for any type when every append is a multiple of 8 bytes.
// No R API.
int zuregex_arena_reserve(zuregex_arena *a, size_t n);

// One match: pcre2_jit_match() when the pattern is JIT-compiled and the
// options allow it, otherwise pcre2_match(). Returns 1 for a match, 0 for none, -1 for an error
// recorded in *st.
int zuregex_match_once(const zuregex_call *call, const zuregex_pattern *p,
                       const zuregex_subject *s, size_t start,
                       uint32_t options, pcre2_match_data *md,
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

// The first element error in `status`, if any, as a condition description
// for the R side: list(kind, element, rc, offset, message). Returns
// R_NilValue when every element succeeded. With on_limit = "na", limit
// errors are not errors: their elements are NA, and zuregex_limited()
// counts them.
SEXP zuregex_status_error(const zuregex_call *call,
                          const zuregex_status *status);

int zuregex_is_limit(int rc);

// The error description for a result that would hold a NUL byte, or be
// longer than an R string can be, at 1-based `element`.
SEXP zuregex_nul_error(R_xlen_t element);
SEXP zuregex_too_long_error(R_xlen_t element);
double zuregex_limited(const zuregex_call *call, const zuregex_status *status);

// list(value, error, limited), as every verb returns to R.
SEXP zuregex_result(const zuregex_call *call, const zuregex_status *status,
                    SEXP value, SEXP error);

#endif

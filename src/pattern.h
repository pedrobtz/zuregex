#ifndef ZUREGEX_PATTERN_H
#define ZUREGEX_PATTERN_H

// A compiled pattern and the key it was compiled from. No R API here: the
// match loops of later stages read these from worker threads.

#include <stddef.h>
#include <stdint.h>

#include "pcre2.h"

enum { ZUREGEX_DIALECT_PCRE = 0, ZUREGEX_DIALECT_JS = 1 };

// What a pattern is compiled from. Two keys that compare equal compile to
// the same code, which is what makes them a cache key.
typedef struct {
  const char *pattern;  // UTF-8, not necessarily NUL-terminated
  size_t length;        // in bytes
  uint32_t options;     // compile options from the flag letters
  uint32_t extra;       // extra compile options from the flag letters
  int dialect;
  int literal;
  int jit;              // JIT compilation requested
} zuregex_key;

// Shared by the cache and by every `re` object that refers to it. Its
// reference count is touched on the main thread only (design section 6.4):
// by the cache, by re_compile() and by external-pointer finalizers.
typedef struct zuregex_pattern {
  pcre2_code *code;
  int refs;
  char *pattern;  // owned copy of key.pattern, NUL-terminated
  zuregex_key key;
  int jit_in_use;
  uint64_t last_used;  // cache recency
} zuregex_pattern;

// Flag letters to options. Returns 0 on success, or the one-based position
// of the first letter that is unknown, repeated or not allowed with
// `literal`.
int zuregex_parse_flags(const char *flags, int literal, uint32_t *options,
                        uint32_t *extra);

// Options back to canonical flag letters; buf needs 32 bytes.
void zuregex_format_flags(uint32_t options, uint32_t extra, char *buf);

// Compiles a pattern with refs = 1. On failure returns NULL and sets
// *errcode (a PCRE2 error code) and *erroffset (in bytes).
zuregex_pattern *zuregex_pattern_compile(const zuregex_key *key, int *errcode,
                                         size_t *erroffset);

void zuregex_pattern_retain(zuregex_pattern *p);
void zuregex_pattern_release(zuregex_pattern *p);

// The cache (cache.c). Returns a pattern the caller owns one reference to,
// compiling it on a miss; NULL on a compile error, as above.
zuregex_pattern *zuregex_cache_get(const zuregex_key *key, int *errcode,
                                   size_t *erroffset);
int zuregex_cache_capacity(void);
int zuregex_cache_set_capacity(int capacity);  // returns the previous one
int zuregex_cache_clear(void);                 // returns how many it held

typedef struct {
  int size, capacity;
  double hits, misses, evictions;
} zuregex_cache_stats;
zuregex_cache_stats zuregex_cache_get_stats(void);

#define ZUREGEX_CACHE_MAX 256
#define ZUREGEX_CACHE_DEFAULT 128
#define ZUREGEX_CACHE_MAX_PATTERN 65536  // characters

#endif

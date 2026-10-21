# Stage 2 plan: compile, flags and the cache

Scratch plan; the roadmap is authoritative. Red/green command:
`Rscript -e 'devtools::test(filter = "<name>")'`.

## Shape

- C struct `zuregex_pattern`: `pcre2_code *code`, `int refs`, the key
  (pattern bytes, flags string, dialect, literal, jit), `int jit_in_use`.
  Owned by reference count: the cache holds one reference, each `re`
  external pointer holds one. Finalizer drops one. Main thread only.
- `re` object: a list of external pointers (NULL pointer for an `NA`
  pattern) with class `"re"` and attributes `pattern`, `flags`,
  `dialect`, `literal`, `jit`. Methods: `format`, `print`, `[`, `length`
  (list default), `as.character`.
- Flags are parsed in C (`zuregex_flags_parse`) into compile and extra
  option words; an unknown letter returns its position and R raises
  `zuregex_error_flags`. With `literal = TRUE` only `i` and `r` are
  accepted (PCRE2_LITERAL's mask); dialect options are dropped.
- Cache: a fixed array of 256 slots, LRU by a use counter, keyed by the
  full key. Patterns over 65,536 characters bypass it. `re_cache_size()`
  gets/sets the capacity (0 to 256; shrinking evicts), `re_cache_clear()`
  empties it. An internal `cache_stats()` reports size, capacity, hits,
  misses and evictions for tests.
- Errors: `zuregex_error` root; `zuregex_error_compile` with `pattern`,
  `element`, `offset` (one-based characters) and `pcre2_message`; the
  message shows the pattern with a caret. `zuregex_error_flags`.
  `zuregex_error_argument` for bad argument types.
- `re_info(re)`: a data frame, one row per pattern: pattern, flags (from
  PCRE2_INFO_ARGOPTIONS/EXTRAOPTIONS, so the round trip is real), dialect,
  literal, groups, group_names (list), jit, min_length, prefix,
  backrefs, pcre2_version.
- `re_escape(x)`.

## Tasks

1. Condition helpers and `zuregex_error_*` classes (R/errors.R).
2. Flag parsing in C + `re_compile()` without cache; round-trip test of
   every letter through `re_info()`.
3. Compile errors with offsets and caret, invalid patterns at several
   offsets including non-ASCII.
4. `re` methods: format, print, `[`, as.character; NA patterns.
5. Cache with refcounts: hits, eviction at capacity, over-length bypass,
   clear, size get/set, cached vs uncached `re_info()` equality.
6. `re_escape()` round trip over all ASCII punctuation and with `x` flag.
7. `literal` prefix in `re_info()`.
8. Benchmark test (skip on CRAN): cached compile < 5% of uncached.
9. Docs, NEWS, roadmap, gctorture/valgrind locally where cheap.

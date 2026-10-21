# zuregex (development version)

* Bundles PCRE2 10.48, the 8-bit library with its JIT compiler, built without
  CMake and with every PCRE2 symbol hidden from R's own copy.
* `zuregex_info()` reports the bundled PCRE2 version and whether its JIT
  compiler works on this machine.
* `re_compile()` compiles patterns, with flag letters, a JavaScript dialect,
  literal patterns and JIT compilation, into `re` objects that survive
  `saveRDS()`. `re_info()` describes them, and `re_escape()` quotes
  metacharacters.
* Compiled patterns are cached, 128 by default; `re_cache_size()` and
  `re_cache_clear()` manage the cache.
* Errors are classed conditions inheriting from `zuregex_error`. An invalid
  pattern raises `zuregex_error_compile`, which shows where PCRE2 found the
  error.
* `re_detect()` and `re_count()` match character vectors, raw vectors and
  lists of raw vectors, with one pattern for every element or one per
  element. `anchor` gives Python's `match()` and `fullmatch()`. Invalid
  UTF-8 raises `zuregex_error_utf`, naming the element and byte.
* `re_locate()` and `re_locate_all()` return one-based, inclusive offsets in
  characters or bytes, so `substr()` extracts each match. `re_locate_all()`
  takes `n` and `overlap`, and follows JavaScript's rule for empty matches
  with `dialect = "js"`, as `re_count()` now does.
* `re_extract()`, `re_extract_all()`, `re_match()` and `re_match_all()`
  return matches and capture groups as vectors and data frames built in C.
  `re_match()` takes a `proto` for typed columns, as `utils::strcapture()`
  does, and is about 17 times faster than it on 100,000 strings.

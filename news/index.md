# Changelog

## zuregex (development version)

- Bundles PCRE2 10.48, the 8-bit library with its JIT compiler, built
  without CMake and with every PCRE2 symbol hidden from R’s own copy.
- [`zuregex_info()`](https://pedrobtz.github.io/zuregex/reference/zuregex_info.md)
  reports the bundled PCRE2 version and whether its JIT compiler works
  on this machine.
- [`re_compile()`](https://pedrobtz.github.io/zuregex/reference/re_compile.md)
  compiles patterns, with flag letters, a JavaScript dialect, literal
  patterns and JIT compilation, into `re` objects that survive
  [`saveRDS()`](https://rdrr.io/r/base/readRDS.html).
  [`re_info()`](https://pedrobtz.github.io/zuregex/reference/re_info.md)
  describes them, and
  [`re_escape()`](https://pedrobtz.github.io/zuregex/reference/re_escape.md)
  quotes metacharacters.
- Compiled patterns are cached, 128 by default;
  [`re_cache_size()`](https://pedrobtz.github.io/zuregex/reference/re_cache_size.md)
  and
  [`re_cache_clear()`](https://pedrobtz.github.io/zuregex/reference/re_cache_size.md)
  manage the cache.
- Errors are classed conditions inheriting from `zuregex_error`. An
  invalid pattern raises `zuregex_error_compile`, which shows where
  PCRE2 found the error.
- [`re_detect()`](https://pedrobtz.github.io/zuregex/reference/re_detect.md)
  and
  [`re_count()`](https://pedrobtz.github.io/zuregex/reference/re_detect.md)
  match character vectors, raw vectors and lists of raw vectors, with
  one pattern for every element or one per element. `anchor` gives
  Python’s [`match()`](https://rdrr.io/r/base/match.html) and
  `fullmatch()`. Invalid UTF-8 raises `zuregex_error_utf`, naming the
  element and byte.

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

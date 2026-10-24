# zuregex 0.1.0

* Initial CRAN submission.

## The engine

* Bundles PCRE2 10.48, the 8-bit library with its JIT compiler, built
  without CMake and with every PCRE2 symbol hidden from R's own copy.
  `zuregex_info()` reports the version, whether the JIT compiler works on
  this machine, OpenMP, the thread cap and the cache size.

## Compiling

* `re_compile()` compiles patterns with flag letters, a JavaScript dialect,
  literal patterns and JIT compilation into `re` objects, which survive
  `saveRDS()`. `re_info()` describes them, and `re_escape()` quotes
  metacharacters.
* `\C`, which matches one byte, is a compile error in a pattern matched
  as UTF-8, because it could split a character. Bytes patterns allow it.
* Patterns are cached, 128 by default; `re_cache_size()` and
  `re_cache_clear()` manage the cache.

## Matching

* `re_detect()`, `re_count()`, `re_locate()` and `re_locate_all()` match
  character vectors, raw vectors and lists of raw vectors, with one pattern
  for every element or one per element. Offsets are one-based and
  inclusive, in characters or bytes.
* `re_extract()`, `re_extract_all()`, `re_match()` and `re_match_all()`
  return matches and capture groups as vectors and data frames built in C.
  `re_match()` types its columns through `proto`, as `utils::strcapture()`
  does.
* Every verb takes `flags` and `literal`, as `re_compile()` does, so
  `re_detect(x, "abc", flags = "i")` is base R's `ignore.case = TRUE` and
  `literal = TRUE` is its `fixed = TRUE`. An `re` object carries its own.
* `re_replace()` uses PCRE2's extended templates (`$1`, `${name}`,
  `${1:-default}`, `${1:+yes:no}`, case forcing), literal text, or a
  function called once with every match. `re_expand()` expands a template
  with the first match, and `re_split()` splits as Python's `re.split()`
  does.
* `re_limits()` bounds the work of a match, per call or through the
  `zuregex.limits` option. An element that hits a limit raises
  `zuregex_error_limit`, or gives `NA` and one warning with
  `on_limit = "na"`.
* Matching runs on several threads with OpenMP on large inputs, with the
  same results on any number of threads; `re_threads()` caps them. On
  macOS that uses the `libomp` R ships, as CRAN builds it.
  `zuregex_info()` reports whether OpenMP is on, the threads and cores it
  can use, and the input size below which a call stays on one thread.
  A forked child, such as a `parallel::mclapply()` worker, matches on one
  thread.
* Each call does little work outside the match itself. Subjects that R
  marks as ASCII skip PCRE2's UTF-8 check, results are built in one buffer
  per thread, and a call with one pattern string is a single `.Call`.
  Extraction and captures are 10 to 40 times faster than base R's
  `perl = TRUE`. Detection, replacement, splitting and calls on a few
  strings run about level with base R and stringi, a little ahead or
  behind depending on the platform.
* Errors are classed conditions inheriting from `zuregex_error`.

## For other packages

* A C API through `LinkingTo: zuregex` and `<zuregex-r.h>`: compile, match,
  read offsets, substitute and set limits through opaque `zr_pattern` and
  `zr_match_data` handles, so an upgrade of the bundled PCRE2 never changes
  a consumer's build. Offsets there are zero-based, half-open and in bytes.

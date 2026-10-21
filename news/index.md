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
- [`re_locate()`](https://pedrobtz.github.io/zuregex/reference/re_locate.md)
  and
  [`re_locate_all()`](https://pedrobtz.github.io/zuregex/reference/re_locate.md)
  return one-based, inclusive offsets in characters or bytes, so
  [`substr()`](https://rdrr.io/r/base/substr.html) extracts each match.
  [`re_locate_all()`](https://pedrobtz.github.io/zuregex/reference/re_locate.md)
  takes `n` and `overlap`, and follows JavaScript’s rule for empty
  matches with `dialect = "js"`, as
  [`re_count()`](https://pedrobtz.github.io/zuregex/reference/re_detect.md)
  now does.
- [`re_extract()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md),
  [`re_extract_all()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md),
  [`re_match()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
  and
  [`re_match_all()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
  return matches and capture groups as vectors and data frames built
  in C.
  [`re_match()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
  takes a `proto` for typed columns, as
  [`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html) does,
  and is about 17 times faster than it on 100,000 strings.
- [`re_replace()`](https://pedrobtz.github.io/zuregex/reference/re_replace.md)
  replaces matches with PCRE2’s extended templates (`$1`, `${name}`,
  `${1:-default}`, `${1:+yes:no}`, case forcing), literal text, or a
  function called once with every match.
  [`re_expand()`](https://pedrobtz.github.io/zuregex/reference/re_replace.md)
  expands a template with the first match, and
  [`re_split()`](https://pedrobtz.github.io/zuregex/reference/re_split.md)
  splits as Python’s `re.split()` does. Template errors raise
  `zuregex_error_template`.
- [`re_limits()`](https://pedrobtz.github.io/zuregex/reference/re_limits.md)
  bounds the work of a match, through `limits =` on every verb or the
  `zuregex.limits` option. An element that hits a limit raises
  `zuregex_error_limit`, or gives `NA` and one warning per call with
  `on_limit = "na"`.
- Matching runs on several threads with OpenMP when a call’s subjects
  pass an internal size threshold, with identical results at any thread
  count.
  [`re_threads()`](https://pedrobtz.github.io/zuregex/reference/re_threads.md)
  caps the threads;
  [`zuregex_info()`](https://pedrobtz.github.io/zuregex/reference/zuregex_info.md)
  reports `openmp`, `threads` and `cache_size`.

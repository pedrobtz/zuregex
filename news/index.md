# Changelog

## zuregex 0.1.0

- Initial CRAN submission.

### The engine

- Bundles PCRE2 10.48, the 8-bit library with its JIT compiler, built
  without CMake and with every PCRE2 symbol hidden from R’s own copy.
  [`zuregex_info()`](https://pedrobtz.github.io/zuregex/reference/zuregex_info.md)
  reports the version, whether the JIT compiler works on this machine,
  OpenMP, the thread cap and the cache size.

### Compiling

- [`re_compile()`](https://pedrobtz.github.io/zuregex/reference/re_compile.md)
  compiles patterns with flag letters, a JavaScript dialect, literal
  patterns and JIT compilation into `re` objects, which survive
  [`saveRDS()`](https://rdrr.io/r/base/readRDS.html).
  [`re_info()`](https://pedrobtz.github.io/zuregex/reference/re_info.md)
  describes them, and
  [`re_escape()`](https://pedrobtz.github.io/zuregex/reference/re_escape.md)
  quotes metacharacters.
- Patterns are cached, 128 by default;
  [`re_cache_size()`](https://pedrobtz.github.io/zuregex/reference/re_cache_size.md)
  and
  [`re_cache_clear()`](https://pedrobtz.github.io/zuregex/reference/re_cache_size.md)
  manage the cache.

### Matching

- [`re_detect()`](https://pedrobtz.github.io/zuregex/reference/re_detect.md),
  [`re_count()`](https://pedrobtz.github.io/zuregex/reference/re_detect.md),
  [`re_locate()`](https://pedrobtz.github.io/zuregex/reference/re_locate.md)
  and
  [`re_locate_all()`](https://pedrobtz.github.io/zuregex/reference/re_locate.md)
  match character vectors, raw vectors and lists of raw vectors, with
  one pattern for every element or one per element. Offsets are
  one-based and inclusive, in characters or bytes.
- [`re_extract()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md),
  [`re_extract_all()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md),
  [`re_match()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
  and
  [`re_match_all()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
  return matches and capture groups as vectors and data frames built
  in C.
  [`re_match()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
  types its columns through `proto`, as
  [`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html) does.
- [`re_replace()`](https://pedrobtz.github.io/zuregex/reference/re_replace.md)
  uses PCRE2’s extended templates (`$1`, `${name}`, `${1:-default}`,
  `${1:+yes:no}`, case forcing), literal text, or a function called once
  with every match.
  [`re_expand()`](https://pedrobtz.github.io/zuregex/reference/re_replace.md)
  expands a template with the first match, and
  [`re_split()`](https://pedrobtz.github.io/zuregex/reference/re_split.md)
  splits as Python’s `re.split()` does.
- [`re_limits()`](https://pedrobtz.github.io/zuregex/reference/re_limits.md)
  bounds the work of a match, per call or through the `zuregex.limits`
  option. An element that hits a limit raises `zuregex_error_limit`, or
  gives `NA` and one warning with `on_limit = "na"`.
- Matching runs on several threads with OpenMP on large inputs, with the
  same results on any number of threads;
  [`re_threads()`](https://pedrobtz.github.io/zuregex/reference/re_threads.md)
  caps them.
- Each call does little work outside the match itself. Subjects that R
  marks as ASCII skip PCRE2’s UTF-8 check, results are built in one
  buffer per thread, and a call with one pattern string is a single
  `.Call`. Extraction and captures are 10 to 40 times faster than base
  R’s `perl = TRUE`. Detection, replacement, splitting and calls on a
  few strings run about level with base R and stringi, a little ahead or
  behind depending on the platform.
- Errors are classed conditions inheriting from `zuregex_error`.

### For other packages

- A C API through `LinkingTo: zuregex` and `<zuregex-r.h>`: compile,
  match, read offsets, substitute and set limits through opaque
  `zr_pattern` and `zr_match_data` handles, so an upgrade of the bundled
  PCRE2 never changes a consumer’s build. Offsets there are zero-based,
  half-open and in bytes.

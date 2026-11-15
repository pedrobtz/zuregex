# zuregex

zuregex is a regular expression package that matches with a bundled
[PCRE2](https://github.com/PCRE2Project/pcre2), the same version on
every platform, from R and from C.

Base R’s `perl = TRUE` uses PCRE2 too. zuregex adds what that leaves
out:

- Capture groups come back as a data frame, one column per group.
- A pattern is compiled once and cached, and matching runs on several
  threads where the build has OpenMP.
- Replacements use PCRE2’s full template language: groups by name, past
  nine, with defaults and case forcing.
- Other packages reach the same PCRE2 from C through `LinkingTo`,
  instead of bundling a copy.

## Installation

Install zuregex from CRAN with:

``` r

install.packages("zuregex")
```

Or install the development version from
[GitHub](https://github.com/pedrobtz/zuregex) with:

``` r

# install.packages("pak")
pak::pak("pedrobtz/zuregex")
```

## Usage

``` r

library(zuregex)
```

[`re_match()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
turns the named groups of a pattern into the columns of a data frame,
one row per string. The last string is not a log line, so its row is
`NA`.

``` r

log <- c(
  "2026-10-21 08:15:02 GET /index.html 200 512",
  "2026-10-21 08:15:09 POST /login 302 0",
  "2026-10-21 08:16:44 GET /missing 404 128",
  "not a log line"
)
pattern <- "(?<time>\\S+ \\S+) (?<method>[A-Z]+) (?<path>\\S+) (?<status>\\d+)"
re_match(log, pattern)
#>                  time method        path status
#> 1 2026-10-21 08:15:02    GET /index.html    200
#> 2 2026-10-21 08:15:09   POST      /login    302
#> 3 2026-10-21 08:16:44    GET    /missing    404
#> 4                <NA>   <NA>        <NA>   <NA>
```

zuregex also detects, extracts, replaces and splits with the same
patterns; [Get
started](https://pedrobtz.github.io/zuregex/articles/zuregex.html) walks
through them on this log.

## Learn more

- [Get
  started](https://pedrobtz.github.io/zuregex/articles/zuregex.html)
  takes the log above through every main function.
- [Move from base R and
  stringr](https://pedrobtz.github.io/zuregex/articles/from-base-r.html)
  maps [`grepl()`](https://rdrr.io/r/base/grep.html),
  [`sub()`](https://rdrr.io/r/base/grep.html),
  [`regmatches()`](https://rdrr.io/r/base/regmatches.html) and the
  `str_*()` functions onto `re_*()`, and shows what behaves differently.
- [Bound the work of a
  match](https://pedrobtz.github.io/zuregex/articles/limits.html) sets
  match, depth and heap limits for patterns or input you do not trust.
- [Link to zuregex from
  C](https://pedrobtz.github.io/zuregex/articles/c-api.html) uses the
  bundled PCRE2 from another package’s C code.
- The [reference index](https://pedrobtz.github.io/zuregex/reference/)
  lists every function, grouped as the API is.

zuregex builds on PCRE2, which backtracks. For matching in linear time,
use [re2](https://CRAN.R-project.org/package=re2).

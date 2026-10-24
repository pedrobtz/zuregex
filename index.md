# zuregex

Base R already matches regular expressions with
[PCRE2](https://github.com/PCRE2Project/pcre2) when you ask for
`perl = TRUE`. But it compiles the pattern again on every call, matches
on one thread, hands back capture groups as attributes you have to take
apart, and knows only `\\1` to `\\9` in replacements. A package that
needs PCRE2 from C has to bundle its own copy, as vectorscan does.

zuregex bundles one PCRE2, the same version on every platform, and
builds on it twice: as `re_*()` functions for R, and as a C API other
packages reach through `LinkingTo`.

- **Captures as data.**
  [`re_match()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
  returns a data frame with a column per group, built in C, and can type
  the columns as
  [`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html) does.
- **Compiled once.** Patterns go through a cache, so a pattern used in a
  loop is compiled once, JIT included.
- **Many cores.** Matching runs on several threads with OpenMP on large
  inputs, with the same results on any number of threads.
- **PCRE2’s full replacement language.** Groups by name, past nine, with
  defaults and conditionals, and case forcing.
- **Bounded work.** Match, depth and heap limits per call, so one
  pathological subject gives an error or an `NA` instead of a stall.

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

Take a few lines from a web server’s log.

``` r

log <- c(
  "2026-10-21 08:15:02 GET /index.html 200 512",
  "2026-10-21 08:15:09 POST /login 302 0",
  "2026-10-21 08:16:44 GET /missing 404 128",
  "not a log line"
)
```

[`re_detect()`](https://pedrobtz.github.io/zuregex/reference/re_detect.md)
and
[`re_count()`](https://pedrobtz.github.io/zuregex/reference/re_detect.md)
work as [`grepl()`](https://rdrr.io/r/base/grep.html) and
[`stringr::str_count()`](https://stringr.tidyverse.org/reference/str_count.html)
do, element by element.

``` r

re_detect(log, "\\s(?:GET|POST)\\s")
#> [1]  TRUE  TRUE  TRUE FALSE
re_count(log, "\\d+")
#> [1] 8 8 8 0
```

[`re_match()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
turns named groups into columns. A line that does not match is a row of
`NA`. `proto` gives the columns types, here an integer status.

``` r

pattern <- "(?<time>\\S+ \\S+) (?<method>[A-Z]+) (?<path>\\S+) (?<status>\\d+)"
re_match(log, pattern)
#>                  time method        path status
#> 1 2026-10-21 08:15:02    GET /index.html    200
#> 2 2026-10-21 08:15:09   POST      /login    302
#> 3 2026-10-21 08:16:44    GET    /missing    404
#> 4                <NA>   <NA>        <NA>   <NA>
typed <- re_match(
  log,
  pattern,
  proto = data.frame(time = "", method = "", path = "", status = 0L)
)
str(typed)
#> 'data.frame':    4 obs. of  4 variables:
#>  $ time  : chr  "2026-10-21 08:15:02" "2026-10-21 08:15:09" "2026-10-21 08:16:44" NA
#>  $ method: chr  "GET" "POST" "GET" NA
#>  $ path  : chr  "/index.html" "/login" "/missing" NA
#>  $ status: int  200 302 404 NA
```

Replacements use PCRE2’s templates: `${name}` for a named group, and
`${n:-default}` for a group that may not take part.

``` r

re_replace(log, "^(?<y>\\d+)-(?<m>\\d+)-(?<d>\\d+)", "${d}/${m}/${y}")
#> [1] "21/10/2026 08:15:02 GET /index.html 200 512"
#> [2] "21/10/2026 08:15:09 POST /login 302 0"      
#> [3] "21/10/2026 08:16:44 GET /missing 404 128"   
#> [4] "not a log line"
re_replace(c("v1.2", "v3"), "v(\\d+)(?:\\.(\\d+))?", "major $1, minor ${2:-0}")
#> [1] "major 1, minor 2" "major 3, minor 0"
```

A function works too. It is called once, with a data frame of every
match.

``` r

re_replace(log, "/\\w+", function(m) toupper(m[["0"]]))
#> [1] "2026-10-21 08:15:02 GET /INDEX.html 200 512"
#> [2] "2026-10-21 08:15:09 POST /LOGIN 302 0"      
#> [3] "2026-10-21 08:16:44 GET /MISSING 404 128"   
#> [4] "not a log line"
```

[`re_compile()`](https://pedrobtz.github.io/zuregex/reference/re_compile.md)
sets flags once:

``` r

re_detect(c("Hello", "hello"), re_compile("HELLO", flags = "i"))
#> [1] TRUE TRUE
```

and
[`re_limits()`](https://pedrobtz.github.io/zuregex/reference/re_limits.md)
bounds the work. `^(a+)+$` backtracks exponentially on a long run of `a`
that ends in something else. With a limit, that element stops early and
gives `NA`, with one warning for the call.

``` r

re_detect(
  c(paste0(strrep("a", 30), "!"), "aaa"),
  "^(a+)+$",
  limits = re_limits(match = 1e4, on_limit = "na")
)
#> Warning in re_detect(c(paste0(strrep("a", 30), "!"), "aaa"), "^(a+)+$", : 1
#> element of `x` hit a match limit and is `NA`.
#> [1]   NA TRUE
```

Every function follows the same pattern: `x` first, then `pattern`,
which is one pattern for every element or one per element, never
recycled.

## From C

Packages that need PCRE2 from C add `zuregex` to `Imports` and
`LinkingTo` and include `<zuregex-r.h>`, instead of bundling their own
copy. Patterns and match data are opaque handles, so an upgrade of the
bundled PCRE2 never changes a consumer’s build. The header documents the
API.

## Learn more

- The [reference index](https://pedrobtz.github.io/zuregex/reference/)
  lists every function, grouped as the API is.
- [`?re_compile`](https://pedrobtz.github.io/zuregex/reference/re_compile.md)
  has the flag letters,
  [`?re_replace`](https://pedrobtz.github.io/zuregex/reference/re_replace.md)
  the template syntax, and
  [`?re_limits`](https://pedrobtz.github.io/zuregex/reference/re_limits.md)
  what limits can and cannot promise.

## Related work

zuregex bundles [PCRE2](https://github.com/PCRE2Project/pcre2) and
checks itself against PCRE2’s own test results, base R’s `perl = TRUE`
and [stringr](https://stringr.tidyverse.org). Its API borrows from
Python’s [pcre2.py](https://github.com/grtetrault/pcre2.py),
JavaScript’s [node-pcre2](https://github.com/segevfiner/node-pcre2) and
Go’s [go-re2](https://github.com/wasilibs/go-re2). For matching in
linear time, which PCRE2 cannot promise, use
[re2](https://CRAN.R-project.org/package=re2).

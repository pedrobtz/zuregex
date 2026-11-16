# Design and motivation

This article is for someone who wonders why R needs another regular
expression package, or who wants to know what zuregex does behind a call
before relying on it. It explains the reasons for the package and the
choices in it. It teaches no function; for that, start with
[`vignette("zuregex")`](https://pedrobtz.github.io/zuregex/articles/zuregex.md).

``` r

library(zuregex)
```

## Why another PCRE2

Base R already matches with
[PCRE2](https://github.com/PCRE2Project/pcre2) when you ask for
`perl = TRUE`. So the pattern syntax is not the reason for zuregex. The
reasons are in what base R does around the engine.

| Base R with `perl = TRUE` | zuregex |
|----|----|
| Compiles the pattern again on every call | Compiles it once and keeps it in a cache |
| Matches on one thread | Matches large inputs on several, where the build has OpenMP |
| Returns groups as attributes of [`regexpr()`](https://rdrr.io/r/base/grep.html) results, to take apart | Returns them as character vectors and data frames, built in C |
| Replacement knows `\\1` to `\\9` | PCRE2’s template language: names, groups past nine, defaults, conditionals, case forcing |
| No limit you can set on the work of a match | Match, depth and heap limits per call |
| Uses the PCRE2 the platform has | Bundles one version |
| Gives packages no way to PCRE2 from C | A C API through `LinkingTo` |

The last row is half the package. A package that needs PCRE2 in its C
code has had to bundle its own copy, as vectorscan does. zuregex is
PCRE2 packaged twice: as `re_*()` functions for R, and as a library for
other packages, described in [Link to zuregex from
C](https://pedrobtz.github.io/zuregex/articles/c-api.html).

## One version on every platform

R takes PCRE2 from the system it was built on, so the version depends on
the platform. zuregex compiles its own copy into the package, with every
PCRE2 symbol hidden so that it cannot be confused with R’s. These are
the two versions on the machine that built this page: the first is the
same wherever zuregex is installed, the second is not.

``` r

zuregex_info()$pcre2_version
#> [1] "10.49"
extSoftVersion()[["PCRE"]]
#> [1] "10.42 2022-12-11"
```

## Compiled once

Compiling a pattern, and JIT-compiling it, costs far more than matching
one short string with it. A call inside
[`lapply()`](https://rdrr.io/r/base/lapply.html) or a Shiny reactive
would pay that each time. So every pattern string goes through a cache
of compiled patterns, keyed by the pattern, its flags and its other
compile-time arguments, and the least recently used one is dropped when
the cache is full. This is its capacity.

``` r

re_cache_size()
#> [1] 128
```

The size follows Python’s PyPcre. An `re` object from
[`re_compile()`](https://pedrobtz.github.io/zuregex/reference/re_compile.md)
holds its compiled pattern itself and stays valid whatever the cache
does.

## Several threads, one answer

A call does its work in three phases. The first reads the R strings, the
second matches, and the third builds the R result. Only the second runs
on several threads, with OpenMP, and it never touches R. That is what
makes it safe, and it is also why results are identical for any number
of threads:
[`re_threads()`](https://pedrobtz.github.io/zuregex/reference/re_threads.md)
is a performance control and nothing else.

A call whose subjects are small stays on one thread, because starting
threads would cost more than it saves.
[`zuregex_info()`](https://pedrobtz.github.io/zuregex/reference/zuregex_info.md)
reports whether a build has OpenMP and where that threshold is.

## What it was checked against

zuregex does not ask to be trusted on its own tests. Its results are
compared with three other implementations:

- PCRE2’s own test data, run through the C API.
- Base R’s `perl = TRUE` and [stringr](https://stringr.tidyverse.org),
  on a shared corpus, with every deliberate difference marked in the
  tests.
- Python’s `re`, for splitting and the other behaviour taken from it.

## Where the API comes from

The functions are new to R but not invented. The compiled pattern object
and
[`re_expand()`](https://pedrobtz.github.io/zuregex/reference/re_replace.md)
follow Python’s [pcre2.py](https://github.com/grtetrault/pcre2.py). The
flag letters and the JavaScript dialect follow
[node-pcre2](https://github.com/segevfiner/node-pcre2). The grid of
verbs, `n` to cap the number of matches, and
[`re_escape()`](https://pedrobtz.github.io/zuregex/reference/re_escape.md)
follow Go’s `regexp` package by way of
[go-re2](https://github.com/wasilibs/go-re2).

## What it leaves out

PCRE2 backtracks, so zuregex makes no promise of linear time; limits
bound the work, as [Bound the work of a
match](https://pedrobtz.github.io/zuregex/articles/limits.html) shows,
and [re2](https://CRAN.R-project.org/package=re2) gives the guarantee.
The full list is under Scope in
[`?zuregex`](https://pedrobtz.github.io/zuregex/reference/zuregex-package.html).

## See also

[Move from base R and
stringr](https://pedrobtz.github.io/zuregex/articles/from-base-r.html)
puts the differences from base R to use, function by function.

# Performance against base R and stringi

This article compares zuregex with base R’s `perl = TRUE` functions and
with [stringi](https://stringi.gagolewski.com/) on eight common tasks.
It is for readers deciding whether the speed difference matters for
their data. The numbers come from one machine. Read them as ratios, not
as times you will see.

## How it was measured

The input is 50,000 synthetic log lines of about 64 ASCII characters.
These are the first two; half the lines have a phone number and half end
in `no phone`.

    login user id=662153 user447@host6.com beta; warn, call 555-5110
    delta beta id=633215 user22@host50.com beta; info, call 555-5676

Each task runs the same pattern through the three packages. The script
first checks that all three give the same result, then times each with
`bench::mark()` and keeps the median. One case is a single string, where
the cost of the call itself dominates.

The machine was Intel(R) Core(TM) i5-8500B CPU @ 3.00GHz
(x86_64-apple-darwin20), running R version 4.6.2 (2026-10-29), on
2026-11-16. It had zuregex 0.1.0 with PCRE2 10.49 and its JIT compiler,
base R’s own PCRE2 10.47 2025-10-21, and stringi 1.8.9 with ICU 71.1.
zuregex ran on 1 thread.

## Results

Median time per call, in milliseconds. The two right-hand columns say
how many times longer the other package took than zuregex, so a value
above 1 means zuregex was faster.

| Task | Input | zuregex | base R | stringi | base R / zuregex | stringi / zuregex |
|:---|:---|---:|---:|---:|---:|---:|
| Detect | 50,000 strings | 10.338 | 12.018 | 34.136 | 1.2 | 3.3 |
| Count matches | 50,000 strings | 18.612 | 327.303 | 45.882 | 17.6 | 2.5 |
| Locate the first match | 50,000 strings | 11.429 | 19.525 | 46.392 | 1.7 | 4.1 |
| Extract every match | 50,000 strings | 45.833 | 768.996 | 78.337 | 16.8 | 1.7 |
| Capture groups | 50,000 strings | 21.058 | 1003.548 | 52.621 | 47.7 | 2.5 |
| Replace every match | 50,000 strings | 30.364 | 41.815 | 87.535 | 1.4 | 2.9 |
| Split | 50,000 strings | 32.859 | 54.504 | 58.067 | 1.7 | 1.8 |
| Detect, one string | 1 string | 0.013 | 0.021 | 0.013 | 1.6 | 1.0 |

The pattern for each task:

| Task | zuregex | base R | stringi |
|----|----|----|----|
| Detect | [`re_detect()`](https://pedrobtz.github.io/zuregex/reference/re_detect.md) | [`grepl()`](https://rdrr.io/r/base/grep.html) | `stri_detect_regex()` |
| Count matches | [`re_count()`](https://pedrobtz.github.io/zuregex/reference/re_detect.md) | [`gregexpr()`](https://rdrr.io/r/base/grep.html), then counting | `stri_count_regex()` |
| Locate the first match | [`re_locate()`](https://pedrobtz.github.io/zuregex/reference/re_locate.md) | [`regexpr()`](https://rdrr.io/r/base/grep.html) | `stri_locate_first_regex()` |
| Extract every match | [`re_extract_all()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md) | [`gregexpr()`](https://rdrr.io/r/base/grep.html) and [`regmatches()`](https://rdrr.io/r/base/regmatches.html) | `stri_extract_all_regex()` |
| Capture groups | [`re_match()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md) | [`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html) | `stri_match_first_regex()` |
| Replace every match | [`re_replace()`](https://pedrobtz.github.io/zuregex/reference/re_replace.md) | [`gsub()`](https://rdrr.io/r/base/grep.html) | `stri_replace_all_regex()` |
| Split | [`re_split()`](https://pedrobtz.github.io/zuregex/reference/re_split.md) | [`strsplit()`](https://rdrr.io/r/base/strsplit.html) | `stri_split_regex()` |
| Detect, one string | [`re_detect()`](https://pedrobtz.github.io/zuregex/reference/re_detect.md) | [`grepl()`](https://rdrr.io/r/base/grep.html) | `stri_detect_regex()` |

## Reading the numbers

The difference from base R is largest where base R needs two steps, a
search and then R code that turns its offsets into counts, strings or
columns: counting, extracting and capturing.
[`strcapture()`](https://rdrr.io/r/utils/strcapture.html) takes both
steps inside one call. zuregex builds those results in C. Where base R
also takes one call, as with
[`grepl()`](https://rdrr.io/r/base/grep.html),
[`regexpr()`](https://rdrr.io/r/base/grep.html),
[`gsub()`](https://rdrr.io/r/base/grep.html) and
[`strsplit()`](https://rdrr.io/r/base/strsplit.html), the two are much
closer.

On a single string the call itself dominates, so the three packages are
within 10 microseconds of each other. zuregex keeps compiled patterns in
a cache, so a pattern used again is not compiled again.

## What the numbers do not show

- **Other machines give other ratios.** The package’s own timing tests
  record that
  [`re_detect()`](https://pedrobtz.github.io/zuregex/reference/re_detect.md)
  was 0.6 times as fast as [`grepl()`](https://rdrr.io/r/base/grep.html)
  on an arm64 Mac, and that short calls run 10 to 25% behind base R on
  Linux, where base R’s call costs less. The two-step tasks were not
  measured elsewhere.
- **More threads change the large cases.** These results are for one
  thread. On a machine with OpenMP, zuregex matches large inputs on
  several threads;
  [`re_threads()`](https://pedrobtz.github.io/zuregex/reference/re_threads.md)
  sets the cap.
- **Patterns differ.** One corpus of short ASCII lines and four patterns
  is a small sample. Time your own patterns on your own data before you
  rely on a ratio.

## Run it yourself

The script is
[`tools/bench/run.R`](https://github.com/pedrobtz/zuregex/blob/main/tools/bench/run.R)
in the source repository. It needs stringi and bench. Run it against an
installed build, because `devtools::load_all()` compiles without
optimisation:

``` sh
R CMD INSTALL --preclean --library=/tmp/zr-bench .
Rscript tools/bench/run.R /tmp/zr-bench
```

It writes `vignettes/articles/benchmarks.csv`, which this article reads.

## See also

- [Move from base R and
  stringr](https://pedrobtz.github.io/zuregex/articles/from-base-r.md)
  maps each base R function to its zuregex verb.
- [`?re_threads`](https://pedrobtz.github.io/zuregex/reference/re_threads.md)
  and
  [`?re_cache_size`](https://pedrobtz.github.io/zuregex/reference/re_cache_size.md)
  describe the two settings that most affect speed.

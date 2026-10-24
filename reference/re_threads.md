# Thread cap for matching

Matching runs on several threads with OpenMP when a call's subjects add
up to more than an internal size threshold, and on one thread below it.
`re_threads()` reports the most threads a call may use; `re_threads(n)`
caps it for the rest of the session. The cap applies only to zuregex's
own matching, not to other OpenMP code in the process.

## Usage

``` r
re_threads(n = NULL)
```

## Arguments

- n:

  `NULL` to query the effective maximum, a whole number of at least 1 to
  cap the threads, or `0` to remove the cap. Values above the machine's
  thread count are allowed and are the same as no cap.

## Value

Querying returns the effective maximum as an integer. Setting returns
the previous cap invisibly, `0` meaning none was set, so
`old <- re_threads(1); re_threads(old)` restores it exactly.

## Details

Results never depend on the number of threads, so this is a performance
control, not a reproducibility one. In a build without OpenMP the value
is always 1 and a cap has no effect;
[`zuregex_info()`](https://pedrobtz.github.io/zuregex/reference/zuregex_info.md)
reports which build this is.

A forked child, such as a worker of
[`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html),
matches on one thread, because GNU OpenMP can hang in a child whose
parent has used it.

## Examples

``` r
re_threads()
#> [1] 4
old <- re_threads(1)
re_threads(old)
```

# Bound the work a match may do

PCRE2 matches by backtracking, so a pattern such as `(a+)+b` can take
time exponential in the length of the subject. zuregex makes no
linear-time promise; for that, use the re2 package. What it promises is
that limits bound the work per element, and that hitting one is either a
classed error or an `NA` you asked for.

## Usage

``` r
re_limits(match = NULL, depth = NULL, heap = NULL, on_limit = c("error", "na"))
```

## Arguments

- match:

  The most times PCRE2's internal match function may be called for one
  search; PCRE2's default is 10,000,000. The JIT compiler honours it
  too.

- depth:

  The deepest backtracking nesting for one search; PCRE2's default
  equals `match`. The JIT compiler ignores it.

- heap:

  The most heap memory, in kibibytes, the interpreter may use for
  backtracking in one search; PCRE2's default is 20,000,000. The JIT
  compiler ignores it.

- on_limit:

  What an element that hits a limit gives: `"error"` raises a
  `zuregex_error_limit` naming the limit and the element; `"na"` gives
  `NA` for that element and one warning of class `zuregex_warning_limit`
  for the call, counting how many did.

## Value

An object of class `re_limits`.

## Details

Pass `re_limits()` as `limits =` to any matching function, or set it for
the session with `options(zuregex.limits = re_limits(...))`. The
argument wins over the option. `NULL` keeps PCRE2's default for that
limit.

## Examples

``` r
x <- strrep("a", 30)
try(re_detect(x, "(a+)+b", limits = re_limits(match = 1000)))
#> [1] FALSE
re_detect(c(x, "ab"), "(a+)+b", limits = re_limits(match = 1000, on_limit = "na"))
#> [1] FALSE  TRUE

old <- options(zuregex.limits = re_limits(match = 1e5))
options(old)
```

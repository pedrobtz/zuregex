# Split strings

Splits each element of `x` at the matches of `pattern`, as Python's
`re.split()` does: an empty match splits too, and with
`keep_groups = TRUE` each separator's groups are kept between the
pieces.

## Usage

``` r
re_split(x, pattern, n = Inf, keep_groups = FALSE, limits = NULL)
```

## Arguments

- x:

  A character vector, a raw vector, or a list of raw vectors. `NA` (or
  `NULL` in a list) gives `NA`.

- pattern:

  A character vector or an `re` vector; see Patterns.

- n:

  The most pieces per element, `Inf` for no limit. The last piece holds
  the rest of the string, as with Go's `Split(n)`; `n = 0` gives no
  pieces.

- keep_groups:

  If `TRUE`, the groups of each separator are inserted after the piece
  before it, `NA` for a group that did not take part.

- limits:

  A
  [`re_limits()`](https://pedrobtz.github.io/zuregex/reference/re_limits.md)
  object, or `NULL` for `getOption("zuregex.limits")` and then PCRE2's
  defaults.

## Value

A list as long as `x` of character vectors; `NA` for an `NA` subject or
pattern.

## Patterns

`pattern` is a character vector of regular expressions, compiled through
the cache with the default options, or an `re` vector from
[`re_compile()`](https://pedrobtz.github.io/zuregex/reference/re_compile.md)
for flags, dialects and literal patterns. It has length 1, used for
every element of `x`, or exactly the length of `x`, pairing `pattern[i]`
with `x[i]`. Any other length is an error: nothing is recycled. An `NA`
pattern gives `NA` for its element.

## Strings and bytes

Character input is matched as UTF-8; strings in other declared encodings
are translated first. Invalid UTF-8 is an error of class
`zuregex_error_utf`. A raw vector is one subject matched as bytes, as is
each element of a list of raw vectors, and so is a character vector with
any element marked as `"bytes"`. Patterns are then compiled without
UTF-8 support, so `.` matches one byte.

## Examples

``` r
re_split(c("a, b,c", "d"), ",\\s*")
#> [[1]]
#> [1] "a" "b" "c"
#> 
#> [[2]]
#> [1] "d"
#> 
re_split("a1b22c", "(\\d+)", keep_groups = TRUE)
#> [[1]]
#> [1] "a"  "1"  "b"  "22" "c" 
#> 
re_split("a-b-c-d", "-", n = 2)
#> [[1]]
#> [1] "a"     "b-c-d"
#> 
```

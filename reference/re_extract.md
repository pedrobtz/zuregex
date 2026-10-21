# Extract matches and capture groups

`re_extract()` returns the first match in each element of `x`, or one of
its groups; `re_extract_all()` returns every match. `re_match()` returns
every group of the first match as a data frame with one row per element;
`re_match_all()` returns one row per match. The strings are built in C,
without the per-match R overhead of
[`regmatches()`](https://rdrr.io/r/base/regmatches.html) or
[`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html).

## Usage

``` r
re_extract(x, pattern, group = 0, limits = NULL)

re_extract_all(x, pattern, group = 0, n = Inf, limits = NULL)

re_match(x, pattern, proto = NULL, limits = NULL)

re_match_all(x, pattern, n = Inf, limits = NULL)
```

## Arguments

- x:

  A character vector, a raw vector, or a list of raw vectors. `NA` (or
  `NULL` in a list) gives `NA`.

- pattern:

  A character vector or an `re` vector; see Patterns.

- group:

  The group to extract: a number, 0 for the whole match, or a group
  name.

- limits:

  A
  [`re_limits()`](https://pedrobtz.github.io/zuregex/reference/re_limits.md)
  object, or `NULL` for `getOption("zuregex.limits")` and then PCRE2's
  defaults.

- n:

  The most matches to return per element, `Inf` for all.

- proto:

  `NULL` for character columns, or a data frame or list with one element
  per group, as for
  [`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html): each
  column is converted with `as.<class>()` for the class of the matching
  element, and takes its name. S4 classes are not supported.

## Value

`re_extract()`: a character vector, `NA` where there is no match.
`re_extract_all()`: a list of character vectors, `NA` for an `NA`
subject or pattern.

`re_match()`: a data frame with one row per subject and one column per
group, all `NA` where there is no match. `re_match_all()`: a data frame
with `element` and `match` columns, then one column per group, one row
per match; a subject with no match has no rows, and an `NA` subject or
pattern one row of `NA`.

Strings from character input are in UTF-8; from bytes they are marked as
`"bytes"`.

## Groups and columns

Groups are numbered from 1; group 0 is the whole match. In `re_match()`
a named group's column takes its name and an unnamed group's column its
number, so `(?<year>\\d+)-(\\d+)` gives the columns `year` and `2`. A
group that did not take part in the match is `NA`.

With one pattern per element, the columns are the union of the patterns'
groups in order of first appearance: groups with the same name share a
column, unnamed groups share a column by position, and an element whose
pattern lacks a group has `NA` there.

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
x <- c("2026-10-21", "1999-01-02 and 2000-03-04", "none", NA)
re_extract(x, "\\d{4}")
#> [1] "2026" "1999" NA     NA    
re_extract(x, "(?<year>\\d{4})-(\\d{2})", group = "year")
#> [1] "2026" "1999" NA     NA    
re_extract_all(x, "\\d{4}")
#> [[1]]
#> [1] "2026"
#> 
#> [[2]]
#> [1] "1999" "2000"
#> 
#> [[3]]
#> character(0)
#> 
#> [[4]]
#> [1] NA
#> 

re_match(x, "(?<year>\\d{4})-(?<month>\\d{2})")
#>   year month
#> 1 2026    10
#> 2 1999    01
#> 3 <NA>  <NA>
#> 4 <NA>  <NA>
re_match(x, "(\\d{4})-(\\d{2})", proto = data.frame(year = 0L, month = 0L))
#>   year month
#> 1 2026    10
#> 2 1999     1
#> 3   NA    NA
#> 4   NA    NA
re_match_all(x, "(?<year>\\d{4})")
#>   element match year
#> 1       1     1 2026
#> 2       2     1 1999
#> 3       2     2 2000
#> 4       4    NA <NA>
```

# Locate matches

`re_locate()` finds the first match in each element of `x`;
`re_locate_all()` finds every match.

## Usage

``` r
re_locate(x, pattern, bytes = FALSE)

re_locate_all(x, pattern, n = Inf, overlap = FALSE, bytes = FALSE)
```

## Arguments

- x:

  A character vector, a raw vector, or a list of raw vectors. `NA` (or
  `NULL` in a list) gives `NA`.

- pattern:

  A character vector or an `re` vector; see Patterns.

- bytes:

  If `TRUE`, offsets count bytes instead of characters.

- n:

  The most matches to return per element, `Inf` for all.

- overlap:

  If `TRUE`, each search starts one character after the start of the
  previous match, so matches may overlap.

## Value

`re_locate()`: an integer matrix with columns `start` and `end` and one
row per subject, `NA` where there is no match.

`re_locate_all()`: a data frame with one row per match and columns
`element` (the subject's index), `match` (the match's number within the
element), `start` and `end`. A subject with no match has no rows; an
`NA` subject or pattern has one row with `match`, `start` and `end`
`NA`.

## Details

Offsets are one-based and inclusive, as
[`regexpr()`](https://rdrr.io/r/base/grep.html) and
[`stringr::str_locate()`](https://stringr.tidyverse.org/reference/str_locate.html)
report them, so `substr(x, start, end)` extracts a match, and for raw
input so does `x[start:end]`. An empty match at position `k` has
`start = k` and `end = k - 1`. Offsets count characters, or bytes with
`bytes = TRUE`; for raw input the two are the same.

After an empty match, the next search follows the pattern's dialect: for
`"pcre"` PCRE2's rule, which first tries for a non-empty match at the
same position, and for `"js"` JavaScript's, which moves on one
character.

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
x <- c("apple pie", "banana", NA)
loc <- re_locate(x, "an+")
loc
#>      start end
#> [1,]    NA  NA
#> [2,]     2   3
#> [3,]    NA  NA
substr(x, loc[, "start"], loc[, "end"])
#> [1] NA   "an" NA  

re_locate_all(x, "[aeiou]")
#>   element match start end
#> 1       1     1     1   1
#> 2       1     2     5   5
#> 3       1     3     8   8
#> 4       1     4     9   9
#> 5       2     1     2   2
#> 6       2     2     4   4
#> 7       2     3     6   6
#> 8       3    NA    NA  NA
re_locate_all("aaaa", "aa", overlap = TRUE)
#>   element match start end
#> 1       1     1     1   2
#> 2       1     2     2   3
#> 3       1     3     3   4
```

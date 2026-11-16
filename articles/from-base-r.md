# Move from base R and stringr

This guide is for someone who already matches regular expressions with
[`grepl()`](https://rdrr.io/r/base/grep.html),
[`sub()`](https://rdrr.io/r/base/grep.html) and
[`regmatches()`](https://rdrr.io/r/base/regmatches.html), or with
stringr, and wants the zuregex call that does the same. It gives the
equivalents in two tables, then shows the differences you would
otherwise find by surprise.

``` r

library(zuregex)
```

## The equivalent functions

Patterns that work in base R with `perl = TRUE` work unchanged: both use
PCRE2. stringr matches with ICU, whose syntax is close but not the same,
so check a pattern that uses anything beyond the common core.

| Task | Base R, `perl = TRUE` | stringr | zuregex |
|----|----|----|----|
| Does it match? | [`grepl()`](https://rdrr.io/r/base/grep.html) | `str_detect()` | [`re_detect()`](https://pedrobtz.github.io/zuregex/reference/re_detect.md) |
| How many matches? | `lengths(gregexpr())` | `str_count()` | [`re_count()`](https://pedrobtz.github.io/zuregex/reference/re_detect.md) |
| Where is the first match? | [`regexpr()`](https://rdrr.io/r/base/grep.html) | `str_locate()` | [`re_locate()`](https://pedrobtz.github.io/zuregex/reference/re_locate.md) |
| Where is every match? | [`gregexpr()`](https://rdrr.io/r/base/grep.html) | `str_locate_all()` | [`re_locate_all()`](https://pedrobtz.github.io/zuregex/reference/re_locate.md) |
| The first match | [`regmatches()`](https://rdrr.io/r/base/regmatches.html) with [`regexpr()`](https://rdrr.io/r/base/grep.html) | `str_extract()` | [`re_extract()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md) |
| Every match | [`regmatches()`](https://rdrr.io/r/base/regmatches.html) with [`gregexpr()`](https://rdrr.io/r/base/grep.html) | `str_extract_all()` | [`re_extract_all()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md) |
| The groups of the first match | [`regmatches()`](https://rdrr.io/r/base/regmatches.html) with [`regexec()`](https://rdrr.io/r/base/grep.html), [`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html) | `str_match()` | [`re_match()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md) |
| The groups of every match | [`gregexec()`](https://rdrr.io/r/base/grep.html) | `str_match_all()` | [`re_match_all()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md) |
| Replace the first match | [`sub()`](https://rdrr.io/r/base/grep.html) | `str_replace()` | `re_replace(n = 1)` |
| Replace every match | [`gsub()`](https://rdrr.io/r/base/grep.html) | `str_replace_all()` | [`re_replace()`](https://pedrobtz.github.io/zuregex/reference/re_replace.md) |
| Split | [`strsplit()`](https://rdrr.io/r/base/strsplit.html) | `str_split()` | [`re_split()`](https://pedrobtz.github.io/zuregex/reference/re_split.md) |
| Quote metacharacters |  | `str_escape()` | [`re_escape()`](https://pedrobtz.github.io/zuregex/reference/re_escape.md) |

Base R’s options become arguments that every `re_*()` function has.

| Base R               | zuregex                                      |
|----------------------|----------------------------------------------|
| `perl = TRUE`        | always on                                    |
| `ignore.case = TRUE` | `flags = "i"`                                |
| `fixed = TRUE`       | `literal = TRUE`                             |
| `invert = TRUE`      | `re_detect(negate = TRUE)`                   |
| `useBytes = TRUE`    | a raw vector, or strings marked as `"bytes"` |

The subject comes first and the pattern second, as in stringr. With
[`grepl()`](https://rdrr.io/r/base/grep.html) and
[`sub()`](https://rdrr.io/r/base/grep.html) it is the other way round.

``` r

x <- c("2026-10-21 GET /index.html", "no date")
grepl("get", x, ignore.case = TRUE, perl = TRUE)
#> [1]  TRUE FALSE
re_detect(x, "get", flags = "i")
#> [1]  TRUE FALSE
```

## Replacement replaces every match

[`re_replace()`](https://pedrobtz.github.io/zuregex/reference/re_replace.md)
is [`gsub()`](https://rdrr.io/r/base/grep.html), not
[`sub()`](https://rdrr.io/r/base/grep.html): it replaces all the matches
unless `n` says otherwise. Compare the first two results, where only the
year changes, with the third.

``` r

sub("\\d+", "#", x, perl = TRUE)
#> [1] "#-10-21 GET /index.html" "no date"
re_replace(x, "\\d+", "#", n = 1)
#> [1] "#-10-21 GET /index.html" "no date"
re_replace(x, "\\d+", "#")
#> [1] "#-#-# GET /index.html" "no date"
```

## Templates use `$`, and know more

A replacement is a template in PCRE2’s syntax, where a group is `$1` or
`${name}`. Base R writes `\\1` and stops at nine groups, with no names.
A base R template still works, since PCRE2 reads `\\1` to `\\9` as
groups too.

``` r

sub("(\\d+)-(\\d+)", "\\2/\\1", x, perl = TRUE)
#> [1] "10/2026-21 GET /index.html" "no date"
re_replace(x, "(?<year>\\d+)-(?<month>\\d+)", "${month}/${year}", n = 1)
#> [1] "10/2026-21 GET /index.html" "no date"
```

A template can also give a default for a group that took no part in the
match. The second version has no minor number, so `${2:-0}` writes `0`.

``` r

re_replace(c("v1.2", "v3"), "v(\\d+)(?:\\.(\\d+))?", "major $1, minor ${2:-0}")
#> [1] "major 1, minor 2" "major 3, minor 0"
```

[`?re_replace`](https://pedrobtz.github.io/zuregex/reference/re_replace.md)
has the whole syntax, and replacement by a function.

## No match is `NA`, not a missing element

[`regmatches()`](https://rdrr.io/r/base/regmatches.html) drops the
elements that did not match, so its result is shorter than its input.
[`re_extract()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
keeps one result per element.

``` r

regmatches(x, regexpr("\\d+", x, perl = TRUE))
#> [1] "2026"
re_extract(x, "\\d+")
#> [1] "2026" NA
```

## Groups come back as a data frame

`str_match()` returns a character matrix whose first column is the whole
match.
[`re_match()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
returns a data frame of the groups only, named after them.

``` r

stringr::str_match(x, "(?<year>\\d+)-(?<month>\\d+)")
#>                year   month
#> [1,] "2026-10" "2026" "10" 
#> [2,] NA        NA     NA
re_match(x, "(?<year>\\d+)-(?<month>\\d+)")
#>   year month
#> 1 2026    10
#> 2 <NA>  <NA>
```

With `proto` it does the work of
[`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html), and
the two calls give the same typed data frame.

``` r

proto <- data.frame(year = 0L, month = 0L)
utils::strcapture("(\\d+)-(\\d+)", x, proto, perl = TRUE)
#>   year month
#> 1 2026    10
#> 2   NA    NA
re_match(x, "(\\d+)-(\\d+)", proto = proto)
#>   year month
#> 1 2026    10
#> 2   NA    NA
```

## Patterns are never recycled

Base R uses only the first pattern of several, with a warning. zuregex
follows stringr: a pattern has length one or the length of `x`. Anything
else is an error, here three patterns for two strings.

``` r

re_detect(x, c("GET", "POST", "PUT"))
#> Error in `re_detect()`:
#> ! `pattern` must have length 1 or the length of `x` (2), not 3.
```

## Splitting keeps a trailing empty piece

[`strsplit()`](https://rdrr.io/r/base/strsplit.html) drops an empty
string after the last separator.
[`re_split()`](https://pedrobtz.github.io/zuregex/reference/re_split.md)
keeps it, as Python’s `re.split()` and
[`stringr::str_split()`](https://stringr.tidyverse.org/reference/str_split.html)
do.

``` r

strsplit("a,b,", ",", perl = TRUE)
#> [[1]]
#> [1] "a" "b"
re_split("a,b,", ",")
#> [[1]]
#> [1] "a" "b" ""
```

## See also

[`?re_detect`](https://pedrobtz.github.io/zuregex/reference/re_detect.md)
describes the arguments every function shares. For the reasons behind
these choices, read [Design and
motivation](https://pedrobtz.github.io/zuregex/articles/design.html).

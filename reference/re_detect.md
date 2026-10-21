# Detect and count matches

`re_detect()` reports whether each element of `x` matches its pattern.
`re_count()` counts the non-overlapping matches in each element.

## Usage

``` r
re_detect(x, pattern, anchor = c("none", "start", "full"), negate = FALSE)

re_count(x, pattern)
```

## Arguments

- x:

  A character vector, a raw vector, or a list of raw vectors. `NA` (or
  `NULL` in a list) gives `NA`.

- pattern:

  A character vector or an `re` vector; see Patterns.

- anchor:

  Where a match must be: `"none"` anywhere, `"start"` at the start of
  the subject (Python's `re.match()`), `"full"` the whole subject
  (Python's `re.fullmatch()`). Anchoring is done by PCRE2, so it holds
  for every branch of a top-level alternation.

- negate:

  If `TRUE`, return `TRUE` for elements that do not match.

## Value

`re_detect()`: a logical vector, one per subject. `re_count()`: an
integer vector, one per subject.

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
x <- c("apple", "banana", "cherry", NA)
re_detect(x, "an")
#> [1] FALSE  TRUE FALSE    NA
re_detect(x, "a|b", anchor = "start")
#> [1]  TRUE  TRUE FALSE    NA
re_count(x, "[aeiou]")
#> [1]  2  3  1 NA

# One pattern per element
re_detect(c("abc", "abc"), c("^a", "^b"))
#> [1]  TRUE FALSE
```

# Detect and count matches

`re_detect()` reports whether each element of `x` matches its pattern.
`re_count()` counts the non-overlapping matches in each element.

## Usage

``` r
re_detect(
  x,
  pattern,
  anchor = c("none", "start", "full"),
  negate = FALSE,
  flags = "",
  literal = FALSE,
  limits = NULL
)

re_count(x, pattern, flags = "", literal = FALSE, limits = NULL)
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

- flags:

  A single string of flag letters for pattern strings, such as `"i"` for
  case-insensitive matching; see
  [`re_compile()`](https://pedrobtz.github.io/zuregex/reference/re_compile.md)
  for every letter. It applies to every pattern in the call.

- literal:

  If `TRUE`, each pattern string is matched as literal text, with no
  metacharacters, as base R's `fixed = TRUE`. Only the flags `i` and `r`
  apply to a literal pattern.

- limits:

  A
  [`re_limits()`](https://pedrobtz.github.io/zuregex/reference/re_limits.md)
  object, or `NULL` for `getOption("zuregex.limits")` and then PCRE2's
  defaults.

## Value

`re_detect()`: a logical vector, one per subject. `re_count()`: an
integer vector, one per subject.

## Patterns

`pattern` is a character vector of regular expressions, compiled through
the cache with `flags` and `literal`, or an `re` vector from
[`re_compile()`](https://pedrobtz.github.io/zuregex/reference/re_compile.md),
which carries its own flags and can use the JavaScript dialect. It has
length 1, used for every element of `x`, or exactly the length of `x`,
pairing `pattern[i]` with `x[i]`. Any other length is an error: nothing
is recycled. An `NA` pattern gives `NA` for its element.

Base R's options map onto these arguments: `ignore.case = TRUE` is
`flags = "i"`, `fixed = TRUE` is `literal = TRUE`, `invert = TRUE` is
`re_detect(negate = TRUE)`, and `useBytes = TRUE` is a raw vector or
strings marked as `"bytes"` (see Strings and bytes). `perl = TRUE` is
always on.

## Strings and bytes

Character input is matched as UTF-8; strings in other declared encodings
are translated first. Invalid UTF-8 is an error of class
`zuregex_error_utf`. A raw vector is one subject matched as bytes, as is
each element of a list of raw vectors, and so is a character vector with
any element marked as `"bytes"`. Patterns are then compiled without
UTF-8 support, so `.` matches one byte. `\\C`, which matches one byte,
is allowed only then: in a UTF-8 pattern it is a compile error, since it
could split a character. A bytes pattern may not turn UTF-8 back on with
`(*UTF)`.

## Examples

``` r
x <- c("apple", "banana", "cherry", NA)
re_detect(x, "an")
#> [1] FALSE  TRUE FALSE    NA
re_detect(x, "a|b", anchor = "start")
#> [1]  TRUE  TRUE FALSE    NA
re_count(x, "[aeiou]")
#> [1]  2  3  1 NA
re_detect(x, "APPLE", flags = "i")
#> [1]  TRUE FALSE FALSE    NA
re_count("a.b.c", ".", literal = TRUE)
#> [1] 2

# One pattern per element
re_detect(c("abc", "abc"), c("^a", "^b"))
#> [1]  TRUE FALSE
```

# Replace matches

`re_replace()` replaces matches in each element of `x`, all of them by
default. `re_expand()` returns a template expanded with each element's
first match, as Python's `Match.expand()` does.

## Usage

``` r
re_replace(
  x,
  pattern,
  replacement,
  n = Inf,
  syntax = c("extended", "literal"),
  flags = "",
  literal = FALSE,
  limits = NULL
)

re_expand(x, pattern, template, flags = "", literal = FALSE, limits = NULL)
```

## Arguments

- x:

  A character vector, a raw vector, or a list of raw vectors. `NA` (or
  `NULL` in a list) gives `NA`.

- pattern:

  A character vector or an `re` vector; see Patterns.

- replacement:

  A character vector of templates, of length 1 or the length of `x`, or
  a function; see Templates and Replacement functions. An `NA` template
  gives `NA`.

- n:

  The most matches to replace per element, `Inf` for all.

- syntax:

  `"extended"` or `"literal"`; see Templates.

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

- template:

  A character vector of templates, of length 1 or the length of `x`.

## Value

A character vector as long as `x`. Elements without a match are returned
unchanged by `re_replace()` and as `NA` by `re_expand()`. Other strings
are in UTF-8, or marked as `"bytes"` for bytes input.

## Templates

With `syntax = "extended"`, the default, templates use PCRE2's extended
substitution syntax, not base R's `\\1`:

|  |  |
|----|----|
| Template | Meaning |
| `$1`, `${12}`, `${name}` | A group by number, past nine, or by name. `$0` is the whole match. |
| `${1:-none}` | The group, or `none` when it did not take part in the match. |
| `${1:+yes:no}` | `yes` when the group took part, otherwise `no`. |
| `\U...\E`, `\L...\E`, `\u`, `\l` | Upper or lower case until `\E`, or for one character. |
| `$$`, `\$` | A literal `$`. |

A group that did not take part in the match is replaced by `""`. A
reference to a group that does not exist, or a malformed template,
raises `zuregex_error_template` when a match first uses it. With
`syntax = "literal"` the replacement is inserted as it is.

## Replacement functions

`replacement` may be a function. It is called once for the whole call,
if anything matched, with a data frame of every match: `element`,
`match` (its number within the element), `0` (the matched text) and one
column per group, named as in
[`re_match()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md).
A group named `element`, `match` or `0` repeats that column's name, as
in
[`re_match_all()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md).
It must return a character vector with one replacement per row.

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
could split a character.

## Examples

``` r
x <- c("2026-10-21", "no date", NA)
re_replace(x, "(\\d{4})-(\\d{2})-(\\d{2})", "$3/$2/$1")
#> [1] "21/10/2026" "no date"    NA          
re_replace(x, "(?<y>\\d{4})", "${y}!")
#> [1] "2026!-10-21" "no date"     NA           
re_replace("hello world", "(\\w+)", "\\u$1")
#> [1] "Hello World"
re_replace("a1b22", "\\d+", function(m) strrep("#", nchar(m[["0"]])))
#> [1] "a#b##"
re_expand("John Smith", "(\\w+) (\\w+)", "$2, $1")
#> [1] "Smith, John"
```

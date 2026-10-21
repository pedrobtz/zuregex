# Compile regular expressions

`re_compile()` compiles each pattern once, with PCRE2's just-in-time
compiler where the platform allows it, and returns an `re` vector that
every `re_*()` function accepts in place of a character pattern.
Compilation goes through the pattern cache, so compiling the same
pattern again is cheap; see
[`re_cache_size()`](https://pedrobtz.github.io/zuregex/reference/re_cache_size.md).

## Usage

``` r
re_compile(
  pattern,
  flags = "",
  dialect = c("pcre", "js"),
  literal = FALSE,
  jit = TRUE
)
```

## Arguments

- pattern:

  A character vector of regular expressions. `NA` gives an `NA` element.

- flags:

  A single string of flag letters, applied to every pattern:

  |  |  |
  |----|----|
  | Letter | Meaning |
  | `i` | Case-insensitive. |
  | `m` | `^` and `$` match at line boundaries. |
  | `s` | `.` matches a newline. |
  | `x` | Ignore whitespace and allow `#` comments. |
  | `xx` | As `x`, and also ignore whitespace inside character classes. |
  | `n` | Only named groups capture. |
  | `U` | Quantifiers are lazy unless followed by `?`. |
  | `J` | Groups may share a name. |
  | `u` | `\w`, `\d`, `\b` and POSIX classes follow Unicode properties. |
  | `r` | No case equivalence between ASCII and non-ASCII characters. |
  | `aD`, `aS`, `aW` | Keep `\d`, `\s` or `\w` ASCII under `u`. |
  | `aT`, `aP` | Keep POSIX digit classes, or all POSIX classes, ASCII under `u`. |
  | `a` | All five `a` restrictions. |

  Each letter may appear once, and `x` and `xx` exclude each other.

- dialect:

  `"pcre"`, the default, compiles patterns as base R's `perl = TRUE`
  does. `"js"` adds the options node-pcre2 uses for JavaScript patterns:
  `\u` escapes, `$` only at the very end, and unset back-references that
  match the empty string.

- literal:

  If `TRUE`, each pattern is matched as a literal string, with no
  metacharacters. Only the flags `i` and `r` apply to a literal.

- jit:

  If `TRUE`, JIT-compile each pattern when the platform allows it. If
  JIT compilation fails, the interpreter is used and `re_info()$jit` is
  `FALSE`.

## Value

An `re` vector, as long as `pattern`.

## See also

[`re_info()`](https://pedrobtz.github.io/zuregex/reference/re_info.md)
to inspect compiled patterns,
[`re_escape()`](https://pedrobtz.github.io/zuregex/reference/re_escape.md)
to quote metacharacters.

## Examples

``` r
re <- re_compile(c("(\\d+)-(\\d+)", "^[a-z]+$"), flags = "i")
re
#> <re[2]>
#> [1] /(\d+)-(\d+)/i
#> [2] /^[a-z]+$/i
re_info(re)
#>         pattern flags dialect literal groups group_names  jit min_length prefix
#> 1 (\\d+)-(\\d+)     i    pcre   FALSE      2          ,  TRUE          3       
#> 2      ^[a-z]+$     i    pcre   FALSE      0             TRUE          1       
#>   backrefs pcre2_version
#> 1    FALSE         10.48
#> 2    FALSE         10.48

# A literal pattern needs no escaping
re_compile("1+1=2", literal = TRUE)
#> <re[1]>
#> [1] /1+1=2/ (literal)
```

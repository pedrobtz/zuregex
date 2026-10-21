# Describe compiled patterns

Reports what PCRE2 recorded when it compiled each pattern.

## Usage

``` r
re_info(re)
```

## Arguments

- re:

  An `re` vector from
  [`re_compile()`](https://pedrobtz.github.io/zuregex/reference/re_compile.md).

## Value

A data frame with one row per pattern and columns:

- `pattern`, `flags`, `dialect`, `literal`: what was compiled. `flags`
  is rebuilt from PCRE2's options, in a canonical order.

- `groups`: the number of capture groups.

- `group_names`: a list column; for each pattern, a character vector
  with one name per group, `""` for unnamed groups.

- `jit`: whether the pattern runs JIT-compiled code.

- `min_length`: a lower bound on the length of a match, in characters.

- `prefix`: a literal string every match starts with, `""` when there is
  none or it cannot be determined simply. It may be shorter than the
  longest such string.

- `backrefs`: whether the pattern has back-references.

- `pcre2_version`: the PCRE2 version that compiled it.

An `NA` pattern gives a row of `NA`.

## Examples

``` r
re_info(re_compile(c("(?<year>\\d{4})-(\\d{2})", "abc+")))
#>                    pattern flags dialect literal groups group_names  jit
#> 1 (?<year>\\d{4})-(\\d{2})          pcre   FALSE      2      year,  TRUE
#> 2                     abc+          pcre   FALSE      0             TRUE
#>   min_length prefix backrefs pcre2_version
#> 1          7           FALSE         10.48
#> 2          3     ab    FALSE         10.48
```

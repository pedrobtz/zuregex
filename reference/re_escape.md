# Quote regular expression metacharacters

Escapes every character that has a meaning in a PCRE2 pattern, so that
the result matches `x` literally, as Go's `QuoteMeta()` does. The result
is also literal under the `x` flag, which gives whitespace and `#` a
meaning. To match a whole pattern literally, `literal = TRUE` in
[`re_compile()`](https://pedrobtz.github.io/zuregex/reference/re_compile.md)
is simpler.

## Usage

``` r
re_escape(x)
```

## Arguments

- x:

  A character vector. `NA` stays `NA`.

## Value

A character vector as long as `x`, in UTF-8.

## Examples

``` r
re_escape("1+1=2 (really?)")
#> [1] "1\\+1=2\\ \\(really\\?\\)"
```

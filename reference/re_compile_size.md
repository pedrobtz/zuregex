# Cap the size of a compiled pattern

A short pattern can compile to a very large program: counted repeats of
a group copy the group, so nested ones multiply. A 77-character pattern
with three nested `{253}` repeats compiles to 458 MB. zuregex refuses
any pattern whose compiled form would exceed the cap, with a
`zuregex_error_compile`, before PCRE2 allocates the memory.

## Usage

``` r
re_compile_size(bytes = NULL)
```

## Arguments

- bytes:

  `NULL` to query the cap, or a whole number of bytes, at least 1, to
  set it. `Inf` turns the cap off.

## Value

The cap in bytes. When setting it, the previous cap, invisibly.

## Details

The default, 16 MiB, is about a hundred times the largest realistic
pattern: an alternation of keywords at the cache's 65,536-character
limit compiles to about 150 KB. The cap bounds compiling only; to bound
matching, use
[`re_limits()`](https://pedrobtz.github.io/zuregex/reference/re_limits.md).

The cap applies to every compile in the session, including compiles
through the C API. A pattern already in the cache keeps working when the
cap is lowered;
[`re_cache_clear()`](https://pedrobtz.github.io/zuregex/reference/re_cache_size.md)
drops it. An `re` object's pattern is compiled again for bytes subjects
and after [`readRDS()`](https://rdrr.io/r/base/readRDS.html), and that
compile is held to the cap of the moment, so an object made under a
higher cap may refuse raw subjects once the cap is lowered.

## Examples

``` r
re_compile_size()
#> [1] 16777216
try(re_compile("(?:(?:(?:ab|cd){200}){200}){200}"))
#> Error in re_compile("(?:(?:(?:ab|cd){200}){200}){200}") : 
#>   Can't compile pattern: it would compile to more than 16,777,216 bytes. See `?re_compile_size`.
old <- re_compile_size(2^30)
re_compile_size(old)
```

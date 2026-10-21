# The compiled-pattern cache

Every `re_*()` function compiles a character `pattern` through a cache
of recently used compiled patterns, so a pattern used again, in a loop
or across calls, is not recompiled. Patterns are keyed by their text,
`flags`, `dialect`, `literal` and `jit`. The least recently used pattern
is dropped when the cache is full. Patterns longer than 65,536
characters are never cached.

## Usage

``` r
re_cache_size(n = NULL)

re_cache_clear()
```

## Arguments

- n:

  `NULL` to query the capacity, or a whole number from 0 to 256 to set
  it. 0 turns the cache off. Shrinking the cache drops the least
  recently used patterns.

## Value

`re_cache_size()` returns the capacity; when setting it, the previous
capacity, invisibly. `re_cache_clear()` returns the number of patterns
it dropped, invisibly.

## Details

`re` objects from
[`re_compile()`](https://pedrobtz.github.io/zuregex/reference/re_compile.md)
stay valid when the cache drops their pattern or is cleared.

## Examples

``` r
re_cache_size()
#> [1] 128
old <- re_cache_size(16)
re_cache_size(old)
re_cache_clear()
```

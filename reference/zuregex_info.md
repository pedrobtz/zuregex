# Describe the bundled PCRE2 library

Reports the version of PCRE2 that zuregex was built with, whether its
just-in-time (JIT) compiler works on this machine, and how matching is
set up: OpenMP, the thread cap and the cache size.

## Usage

``` r
zuregex_info()
```

## Value

A list with elements:

- `pcre2_version`: the bundled PCRE2 version, such as `"10.48"`.

- `pcre2_date`: its release date.

- `unicode`: whether Unicode and UTF-8 support is built in.

- `unicode_version`: the Unicode version of PCRE2's character tables.

- `jit`: whether the JIT compiler is built in.

- `jit_usable`: whether the JIT compiler works on this machine.

- `jit_target`: the architecture the JIT compiler generates code for, or
  `NA` without it.

- `openmp`: whether this build matches on several threads.

- `threads`: the most threads a call may use; see
  [`re_threads()`](https://pedrobtz.github.io/zuregex/reference/re_threads.md).

- `cache_size`: the pattern cache's capacity; see
  [`re_cache_size()`](https://pedrobtz.github.io/zuregex/reference/re_cache_size.md).

## Details

The JIT compiler can be built in and still fail at run time, on a CPU it
does not support or where the system refuses executable memory. PCRE2
then matches with its interpreter, which gives the same results more
slowly. `jit_usable` tells the two cases apart by JIT-compiling a small
pattern.

## Examples

``` r
zuregex_info()
#> $pcre2_version
#> [1] "10.48"
#> 
#> $pcre2_date
#> [1] "2026-08-31"
#> 
#> $unicode
#> [1] TRUE
#> 
#> $unicode_version
#> [1] "17.0.0"
#> 
#> $jit
#> [1] TRUE
#> 
#> $jit_usable
#> [1] TRUE
#> 
#> $jit_target
#> [1] "x86 64bit (little endian + unaligned)"
#> 
#> $openmp
#> [1] TRUE
#> 
#> $threads
#> [1] 4
#> 
#> $cache_size
#> [1] 128
#> 
```

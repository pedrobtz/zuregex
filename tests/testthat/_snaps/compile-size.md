# a pattern over the cap is a compile error, before any memory

    Code
      re_compile(nested_repeats())
    Condition
      Error in `re_compile()`:
      ! Can't compile pattern: it would compile to more than 16,777,216 bytes. See `?re_compile_size`.

# the C API applies the cap too

    Code
      capi_match(nested_repeats(), "x")
    Condition
      Error in `capi_match()`:
      ! zr_compile: compiled pattern would be longer than the limit set by the application at byte 0

# re_compile_size() checks its argument

    Code
      re_compile_size(0)
    Condition
      Error in `re_compile_size()`:
      ! `bytes` must be `NULL`, `Inf` or a whole number of at least 1, not `0`.


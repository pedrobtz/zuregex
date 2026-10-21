# on_limit = "na" gives NA and one warning per call

    Code
      re_detect(x, case$pattern, limits = lim)
    Condition
      Warning in `re_detect()`:
      2 elements of `x` hit a match limit and are `NA`.
    Output
      [1] TRUE   NA   NA   NA

# re_limits() checks and prints its values

    Code
      print(re_limits(match = 1e+06, heap = 2048, on_limit = "na"))
    Output
      <re_limits> match: 1,000,000, depth: default, heap: 2,048 KiB, on_limit: "na"


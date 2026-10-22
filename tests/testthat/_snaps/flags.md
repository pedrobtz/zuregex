# flag errors name the flags in their message

    Code
      re_detect("a", "a", flags = "iq")
    Condition
      Error in `re_detect()`:
      ! Flag `q` at position 2 of `flags = "iq"` is unknown or repeated.

---

    Code
      re_detect("a", c("a"), flags = "m", literal = TRUE)
    Condition
      Error in `re_detect()`:
      ! Flag `m` at position 1 of `flags = "m"` is unknown, repeated, or not allowed with `literal = TRUE` (only `i` and `r` are).


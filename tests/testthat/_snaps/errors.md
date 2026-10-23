# compile error messages show the pattern with a caret

    Code
      re_compile("ab(c")
    Condition
      Error in `re_compile()`:
      ! Can't compile pattern: missing closing parenthesis at character 5.
        ab(c
            ^

---

    Code
      re_compile(c("ok", "x{2,1}"))
    Condition
      Error in `re_compile()`:
      ! Can't compile pattern 2: numbers out of order in {} quantifier at character 6.
        x{2,1}
             ^

---

    Code
      re_compile("a", flags = "iq")
    Condition
      Error in `re_compile()`:
      ! Flag `q` at position 2 of `flags = "iq"` is unknown or repeated.

---

    Code
      re_compile("a", flags = "m", literal = TRUE)
    Condition
      Error in `re_compile()`:
      ! Flag `m` at position 1 of `flags = "m"` is unknown, repeated, or not allowed with `literal = TRUE` (only `i` and `r` are).

# a long pattern is shown around the error, not in full

    Code
      re_compile(long)
    Condition
      Error in `re_compile()`:
      ! Can't compile pattern: unmatched closing parenthesis at character 202.
        ...aaaaaaaaaaaaaaaaaaaaaaaaaaaaa)bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb...
                                         ^


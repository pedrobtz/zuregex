# a malformed template is a zuregex_error_template with its position

    Code
      re_replace(c("a", "b"), "b", "é${x")
    Condition
      Error in `re_replace()`:
      ! Can't expand the replacement template for element 2: expected closing curly bracket in replacement string at character 5.
        é${x
            ^


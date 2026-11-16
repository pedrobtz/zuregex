# a template error shows the template with a caret

    Code
      re_replace(c("a", "b"), "b", "é${x")
    Condition
      Error in `re_replace()`:
      ! Can't expand the replacement template for element 2: expected closing curly bracket in replacement string at character 5.
        é${x
            ^


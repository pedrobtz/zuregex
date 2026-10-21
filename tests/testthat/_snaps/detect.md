# invalid UTF-8 is a zuregex_error_utf naming element and byte

    Code
      re_detect(c("ok", bad), "c")
    Condition
      Error in `re_detect()`:
      ! Element 2 of `x` is not valid UTF-8 at byte 3: UTF-8 error: illegal byte (0xfe or 0xff).


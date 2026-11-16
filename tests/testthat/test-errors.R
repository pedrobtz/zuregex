# `offset` is where PCRE2 detected the error, as a one-based character
# position. That is usually just after the offending item, and one past the
# end for a pattern that ends too soon.
test_that("an invalid pattern is a zuregex_error_compile with its offset", {
  err <- expect_error(re_compile("ab(c"), class = "zuregex_error_compile")
  expect_s3_class(err, "zuregex_error")
  expect_identical(err$pattern, "ab(c")
  expect_identical(err$element, 1L)
  expect_identical(err$offset, 5L)
  expect_type(err$pcre2_message, "character")

  err <- expect_error(re_compile("a)b"), class = "zuregex_error_compile")
  expect_identical(err$offset, 3L)

  err <- expect_error(re_compile("[z-a]"), class = "zuregex_error_compile")
  expect_identical(err$offset, 5L)
})

test_that("compile offsets count characters, not bytes", {
  err <- expect_error(
    re_compile("\u00e9\u00e9\u00e9)"),
    class = "zuregex_error_compile"
  )
  # Three two-byte characters and the parenthesis: PCRE2 reports byte 7,
  # which is character 5.
  expect_identical(err$offset, 5L)
})

test_that("the failing element is named in a vector of patterns", {
  err <- expect_error(
    re_compile(c("a", "b", "c(")),
    class = "zuregex_error_compile"
  )
  expect_identical(err$element, 3L)
  expect_identical(err$pattern, "c(")
})

test_that("compile error messages show the pattern with a caret", {
  expect_snapshot(re_compile("ab(c"), error = TRUE)
  expect_snapshot(re_compile(c("ok", "x{2,1}")), error = TRUE)
  expect_snapshot(re_compile("a", flags = "iq"), error = TRUE)
  expect_snapshot(re_compile("a", flags = "m", literal = TRUE), error = TRUE)
})

test_that("a long pattern is shown around the error, not in full", {
  long <- paste0(strrep("a", 200), ")", strrep("b", 200))
  err <- expect_error(re_compile(long), class = "zuregex_error_compile")
  expect_identical(err$offset, 202L)
  expect_identical(err$pattern, long)
  expect_snapshot(re_compile(long), error = TRUE)
})

test_that("native() classes an error native code raises without a class", {
  call <- quote(re_detect(x, p))
  err <- expect_error(
    zuregex:::native(stop("boom"), call),
    class = "zuregex_error_native"
  )
  expect_s3_class(err, "zuregex_error")
  expect_identical(err$call, call)
  expect_s3_class(err$parent, "simpleError")
  # A zuregex error passes through with its own class.
  err <- expect_error(
    zuregex:::native(zuregex:::zuregex_abort("limit", "x"), call),
    class = "zuregex_error_limit"
  )
  expect_false(inherits(err, "zuregex_error_native"))
  # Without an error the value comes back.
  expect_identical(zuregex:::native(1L, call), 1L)
})

test_that("a compile error names the user's pattern, not the table's (#170)", {
  err <- expect_error(
    re_detect(c("a", "b", "c", "d"), c("ok", "ok", "(bad", "(bad")),
    class = "zuregex_error_compile"
  )
  expect_identical(err$element, 3L)
  expect_identical(err$pattern, "(bad")
  err <- expect_error(
    re_detect(c("a", "b", "c", "d"), c(NA, "ok", "ok", "(bad")),
    class = "zuregex_error_compile"
  )
  expect_identical(err$element, 4L)
  # An re object recompiled for bytes subjects, with an NA element first.
  r <- re_compile(c(NA, "ok", "(*UTF)x"))
  err <- expect_error(
    re_detect(as.list(charToRaw("abc"))[1:3], r),
    class = "zuregex_error_compile"
  )
  expect_identical(err$element, 3L)
})

test_that("bytes and invalid UTF-8 patterns raise classed errors (#131)", {
  bad <- "a\xff("
  Encoding(bad) <- "UTF-8"
  expect_error(re_compile(bad), class = "zuregex_error_compile")
  expect_error(re_detect("a", bad), class = "zuregex_error_compile")
  expect_error(
    re_detect(c("a", "b"), c(bad, "b")),
    class = "zuregex_error_compile"
  )
  p <- "\x80\x80\x80("
  Encoding(p) <- "bytes"
  err <- expect_error(re_compile(p), class = "zuregex_error_compile")
  err <- expect_error(
    re_detect(charToRaw("abc"), p),
    class = "zuregex_error_compile"
  )
  # The position of a bytes pattern is in bytes.
  expect_identical(err$offset, 5L)
  tm <- "\xff${9"
  Encoding(tm) <- "bytes"
  expect_error(
    re_replace(charToRaw("abc"), "b", tm),
    class = "zuregex_error_template"
  )
  f <- "\xff."
  Encoding(f) <- "UTF-8"
  expect_error(re_compile("a", flags = f), class = "zuregex_error_flags")
  expect_snapshot(re_detect(charToRaw("abc"), p), error = TRUE)
})

test_that("messages do not depend on OutDec (#172)", {
  withr::local_options(OutDec = ",", warn = 2)
  expect_no_error(print(re_limits(match = 1e5)))
  local_compile_size(100)
  expect_error(
    re_compile("(?:(?:ab|cd){20}){20}"),
    class = "zuregex_error_compile"
  )
})

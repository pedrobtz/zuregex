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

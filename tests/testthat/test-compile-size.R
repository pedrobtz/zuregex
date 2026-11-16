test_that("compiled patterns are capped at 16 MiB by default", {
  expect_identical(re_compile_size(), 16 * 2^20)
})

test_that("a pattern over the cap is a compile error, before any memory", {
  local_cache()
  for (dialect in c("pcre", "js")) {
    expect_error(
      re_compile(nested_repeats(), flags = "u", dialect = dialect),
      class = "zuregex_error_compile"
    )
  }
  expect_error(
    re_detect("x", nested_repeats()),
    class = "zuregex_error_compile"
  )
  expect_error(
    re_detect(c("x", "y"), c(nested_repeats(), "y")),
    class = "zuregex_error_compile"
  )
  expect_snapshot(re_compile(nested_repeats()), error = TRUE)
})

test_that("the largest pattern the cache keeps still compiles", {
  local_cache()
  withr::local_seed(1)
  # A keyword alternation, the largest real pattern seen (153 KB compiled).
  words <- replicate(9000, paste(sample(letters, 6, TRUE), collapse = ""))
  p <- paste0("\\b(?:", paste(words, collapse = "|"), ")\\b")
  expect_lte(nchar(p), 65536)
  expect_s3_class(re_compile(p), "re")
  expect_true(re_detect(paste("x", words[[1]], "y"), p))
})

test_that("re_compile_size() sets the cap and returns the previous one", {
  local_cache()
  old <- local_compile_size(1000)
  expect_identical(old, 16 * 2^20)
  expect_identical(re_compile_size(), 1000)
  expect_error(re_compile("(?:ab|cd){100}"), class = "zuregex_error_compile")
  expect_s3_class(re_compile("abc"), "re")
  expect_invisible(re_compile_size(Inf))
  expect_identical(re_compile_size(), Inf)
  expect_s3_class(re_compile("(?:ab|cd){100}"), "re")
})

test_that("a pattern cached under a larger cap stays usable", {
  local_cache()
  p <- "(?:ab|cd){100}"
  expect_false(re_detect("x", p))
  local_compile_size(1000)
  expect_false(re_detect("x", p))
  re_cache_clear()
  expect_error(re_detect("x", p), class = "zuregex_error_compile")
})

test_that("the C API applies the cap too", {
  expect_snapshot(capi_match(nested_repeats(), "x"), error = TRUE)
})

test_that("re_compile_size() checks its argument", {
  for (bad in list(0, -1, 1.5, NA_real_, "1", c(1, 2), NaN, -Inf)) {
    expect_error(re_compile_size(bad), class = "zuregex_error_argument")
  }
  expect_snapshot(re_compile_size(0), error = TRUE)
})

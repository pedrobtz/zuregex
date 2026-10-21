test_that("the big input is above the serial threshold", {
  expect_gt(sum(nchar(big_subjects(), type = "bytes")), 262144)
})

test_that("every verb gives identical results at one thread and at the cap", {
  x <- big_subjects()
  one <- function(f) with_threads(1, f)
  capped <- function(f) with_threads(2, f)
  per_element <- rep_len(
    c("\\d+", "(?<w>[a-z]+)=(\\d+)", "caf.", "a*", "\\s"),
    length(x)
  )
  for (pattern in list("(\\w+)=(\\d+)", per_element)) {
    calls <- list(
      function() re_detect(x, pattern),
      function() re_count(x, pattern),
      function() re_locate(x, pattern),
      function() re_locate_all(x, pattern),
      function() re_extract(x, pattern),
      function() re_extract_all(x, pattern),
      function() re_match(x, pattern),
      function() re_match_all(x, pattern),
      function() re_replace(x, pattern, "<$0>"),
      function() re_replace(x, pattern, function(m) toupper(m[["0"]])),
      function() re_expand(x, pattern, "[$0]"),
      function() re_split(x, pattern, keep_groups = TRUE)
    )
    for (f in calls) {
      expect_identical(capped(f), one(f))
    }
  }
})

test_that("limits give the same NAs at any thread count", {
  case <- pathological()
  x <- rep(c(big_subjects()[1:50], case$x), length.out = 7100)
  lim <- re_limits(match = 1000, on_limit = "na")
  run <- function() {
    suppressWarnings(re_count(x, "(\\w+)=(\\d+)|^(a+)+$", limits = lim))
  }
  expect_identical(with_threads(2, run), with_threads(1, run))
})

test_that("re_threads() gets, caps and restores", {
  old <- re_threads(1)
  withr::defer(re_threads(old))
  expect_identical(re_threads(), 1L)
  expect_identical(re_threads(0), 1L)
  if (zuregex_info()$openmp) {
    expect_gte(re_threads(), 1L)
  } else {
    expect_identical(re_threads(), 1L)
  }
  expect_identical(re_threads(3), 0L)
  for (bad in list(-1, 1.5, NA, "2", c(1, 2))) {
    expect_error(re_threads(bad), class = "zuregex_error_argument")
  }
})

test_that("the suite runs capped at two threads", {
  # tests/testthat/setup.R sets the cap; CRAN allows two threads.
  expect_lte(re_threads(), 2L)
})

test_that("re_detect() on four threads is at least 2.5 times faster than one", {
  skip_unless_timing()
  skip_if_not(zuregex_info()$openmp, "a build without OpenMP")
  old <- re_threads(0)
  withr::defer(re_threads(old))
  skip_if(re_threads() < 4L, "fewer than four threads available")
  withr::local_seed(1)
  x <- vapply(
    seq_len(2e5),
    function(i) {
      paste(sample(c(letters, " "), 120, replace = TRUE), collapse = "")
    },
    ""
  )
  # Backtracking work per element, so the loop is not memory-bound.
  p <- "(\\w+\\s?){3,}z{2}q"
  one <- with_threads(1, function() {
    system.time(a <- re_detect(x, p))[["elapsed"]]
  })
  four <- with_threads(4, function() {
    system.time(b <- re_detect(x, p))[["elapsed"]]
  })
  expect_identical(a, b)
  expect_gt(one / four, 2.5)
})

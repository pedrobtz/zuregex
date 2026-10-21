test_that("every verb stops a pathological match at the match limit", {
  case <- pathological()
  lim <- re_limits(match = 1000)
  for (name in names(every_verb())) {
    verb <- every_verb()[[name]]
    elapsed <- system.time(
      err <- expect_error(
        verb(case$x, case$pattern, limits = lim),
        class = "zuregex_error_limit"
      )
    )[["elapsed"]]
    expect_identical(err$limit, "match", label = name)
    expect_identical(err$element, 1, label = name)
    expect_s3_class(err, "zuregex_error")
    expect_lt(elapsed, 1)
  }
})

test_that("on_limit = \"na\" gives NA and one warning per call", {
  case <- pathological()
  x <- c("aa", case$x, case$x, NA)
  lim <- re_limits(match = 1000, on_limit = "na")
  for (name in names(every_verb())) {
    verb <- every_verb()[[name]]
    warnings <- 0L
    out <- withCallingHandlers(
      verb(x, case$pattern, limits = lim),
      zuregex_warning_limit = function(w) {
        warnings <<- warnings + 1L
        expect_identical(w$count, 2, label = name)
        invokeRestart("muffleWarning")
      }
    )
    expect_identical(warnings, 1L, label = name)
    expect_false(is.null(out), label = name)
  }
  expect_identical(
    re_detect(x, case$pattern, limits = lim) |> suppressWarnings(),
    c(TRUE, NA, NA, NA)
  )
  expect_identical(
    re_count(x, case$pattern, limits = lim) |> suppressWarnings(),
    c(1L, NA, NA, NA)
  )
  loc <- suppressWarnings(re_locate_all(x, case$pattern, limits = lim))
  expect_identical(loc$element, 1:4)
  expect_identical(loc$start, c(1L, NA, NA, NA))
  expect_identical(
    suppressWarnings(re_split(x, case$pattern, limits = lim))[2:3],
    list(NA_character_, NA_character_)
  )
  expect_snapshot(re_detect(x, case$pattern, limits = lim))
})

test_that("the option and the argument behave the same; the argument wins", {
  case <- pathological()
  withr::local_options(zuregex.limits = re_limits(match = 1000))
  expect_error(re_detect(case$x, case$pattern), class = "zuregex_error_limit")
  na <- re_limits(match = 1000, on_limit = "na")
  expect_warning(
    expect_identical(re_detect(case$x, case$pattern, limits = na), NA),
    class = "zuregex_warning_limit"
  )
  withr::local_options(zuregex.limits = na)
  expect_warning(
    re_detect(case$x, case$pattern),
    class = "zuregex_warning_limit"
  )
  # A generous argument lets the match run to completion.
  expect_identical(
    re_detect("aaab", "^(a+)+b$", limits = re_limits(match = 1e7)),
    TRUE
  )
})

test_that("the depth and heap limits are applied", {
  case <- pathological()
  # Depth and heap bound the interpreter; the JIT compiler ignores them.
  re <- re_compile(case$pattern, jit = FALSE)
  err <- expect_error(
    re_detect(case$x, re, limits = re_limits(depth = 10)),
    class = "zuregex_error_limit"
  )
  expect_identical(err$limit, "depth")
  deep <- paste0("^", strrep("(a", 200), strrep(")", 200), "$")
  err <- expect_error(
    re_detect("a", re_compile(deep, jit = FALSE), limits = re_limits(heap = 1)),
    class = "zuregex_error_limit"
  )
  expect_identical(err$limit, "heap")
})

test_that("PCRE2's default limits apply without any", {
  case <- pathological()
  withr::local_options(zuregex.limits = NULL)
  expect_error(re_detect(case$x, case$pattern), class = "zuregex_error_limit")
})

test_that("re_limits() checks and prints its values", {
  expect_s3_class(re_limits(), "re_limits")
  expect_snapshot(print(re_limits(match = 1e6, heap = 2048, on_limit = "na")))
  for (bad in list(0, -1, 1.5, NA, "10", c(1, 2), 2^32)) {
    expect_error(re_limits(match = bad), class = "zuregex_error_argument")
    expect_error(re_limits(depth = bad), class = "zuregex_error_argument")
  }
  expect_error(re_limits(on_limit = "warn"), class = "zuregex_error_argument")
  expect_error(
    re_detect("a", "a", limits = list(match = 1)),
    class = "zuregex_error_argument"
  )
  withr::local_options(zuregex.limits = "tight")
  expect_error(re_detect("a", "a"), class = "zuregex_error_argument")
})

test_that("a replacement function stays aligned around a limited element", {
  case <- pathological()
  x <- c("a1", case$x, "b2c3")
  lim <- re_limits(match = 1000, on_limit = "na")
  seen <- NULL
  out <- NULL
  expect_warning(
    out <- re_replace(
      x,
      "(\\d)|^(a+)+$",
      function(m) {
        seen <<- m
        paste0("<", m[["0"]], ">")
      },
      limits = lim
    ),
    class = "zuregex_warning_limit"
  )
  expect_identical(out, c("a<1>", NA, "b<2>c<3>"))
  expect_identical(seen$element, c(1L, 3L, 3L))
})

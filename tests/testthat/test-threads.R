test_that("the big input is above the serial threshold", {
  expect_gt(
    sum(nchar(big_subjects(), type = "bytes")),
    zuregex:::serial_bytes()
  )
  expect_identical(zuregex:::serial_bytes(), 16384)
})

test_that("small inputs give the same results on the parallel path", {
  x <- parity_subjects()
  run <- function(threads) {
    with_serial_bytes(0, function() {
      with_threads(threads, function() {
        list(
          re_count(x, "\\w+"),
          re_locate_all(x, "[aeiou]"),
          re_match_all(x, "(\\w)(\\w)?"),
          re_replace(x, "(\\w+)", "<$1>"),
          re_split(x, "\\s+")
        )
      })
    })
  }
  expect_identical(run(2), run(1))
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
  x <- rep(c(big_subjects()[1:50], case$x), length.out = 3100)
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
  # A hardware measurement: it needs four dedicated cores. GitHub's shared
  # runners gave 1.99 and 2.19 times; four cores of a laptop gave 3.32
  # (see the roadmap). So it runs only where it is asked for, on a machine
  # that has them, with ZUREGEX_BENCH_THREADS=true as well.
  skip_if_not(
    identical(Sys.getenv("ZUREGEX_BENCH_THREADS"), "true"),
    "set ZUREGEX_BENCH_THREADS=true on a machine with four free cores"
  )
  withr::local_seed(1)
  x <- vapply(
    seq_len(2e5),
    function(i) {
      paste(sample(c(letters, " "), 120, replace = TRUE), collapse = "")
    },
    ""
  )
  # Back-references make each element cost real work, so the loop is not
  # bound by memory bandwidth. Measured at 3.3 times (see the roadmap).
  p <- "(\\w+)\\s(\\w+)\\s\\2\\1"
  timed <- function() {
    value <- NULL
    elapsed <- system.time(value <- re_detect(x, p))[["elapsed"]]
    list(elapsed = elapsed, value = value)
  }
  one <- with_threads(1, timed)
  four <- with_threads(4, timed)
  expect_identical(four$value, one$value)
  expect_gt(one$elapsed / four$elapsed, 2.5)
})

test_that("long results agree with base R at one thread and at the cap", {
  # Many matches per element make each thread's output grow far past its
  # first allocation.
  withr::local_seed(7)
  x <- vapply(
    seq_len(2000),
    function(i) paste(sample(c(letters, 0:9, " "), 400, TRUE), collapse = ""),
    ""
  )
  run <- function(threads) {
    with_threads(threads, function() {
      list(
        re_extract_all(x, "\\d+"),
        re_locate_all(x, "[aeiou]")$start,
        re_replace(x, "(\\d)", "<$1$1>"),
        re_split(x, "\\s+")
      )
    })
  }
  one <- run(1)
  expect_identical(run(2), one)
  expect_identical(one[[1]], regmatches(x, gregexpr("\\d+", x, perl = TRUE)))
  expect_identical(
    one[[2]],
    unlist(lapply(gregexpr("[aeiou]", x, perl = TRUE), as.integer))
  )
  expect_identical(one[[3]], gsub("(\\d)", "<\\1\\1>", x, perl = TRUE))
  # GAP: strsplit() drops a trailing empty piece; re_split() keeps it, as
  # Python does.
  trim <- function(v) {
    if (length(v) > 0 && v[length(v)] == "") v[-length(v)] else v
  }
  expect_identical(lapply(one[[4]], trim), strsplit(x, "\\s+", perl = TRUE))
})

test_that("limited elements between good ones keep no partial results", {
  case <- pathological()
  good <- big_subjects()[1:40]
  x <- rep(c(good, case$x), length.out = 2000)
  bad <- x == case$x
  lim <- re_limits(match = 1000, on_limit = "na")
  p <- "(\\w+)=(\\d+)|^(a+)+$"
  run <- function(threads) {
    with_threads(threads, function() {
      suppressWarnings(list(
        re_extract_all(x, p, limits = lim),
        re_locate_all(x, p, limits = lim),
        re_replace(x, p, "<$0>", limits = lim)
      ))
    })
  }
  one <- run(1)
  expect_identical(run(2), one)
  expect_true(all(is.na(unlist(one[[1]][bad]))))
  expect_true(all(is.na(one[[3]][bad])))
  expect_identical(one[[1]][!bad], re_extract_all(x[!bad], p))
  expect_identical(one[[3]][!bad], re_replace(x[!bad], p, "<$0>"))
})

test_that("a forked child matches on one thread", {
  # GNU OpenMP is not fork-safe: a child that enters a parallel region
  # after its parent used one can hang (#86).
  skip_on_os("windows")
  x <- big_subjects()
  parent <- with_serial_bytes(0, function() re_count(x, "\\d+"))
  child <- parallel::mclapply(
    1:2,
    function(i) list(threads = re_threads(), count = re_count(x, "\\d+")),
    mc.cores = 2
  )
  for (res in child) {
    expect_identical(res$threads, 1L)
    expect_identical(res$count, parent)
  }
})

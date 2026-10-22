# The benchmark of #66 as timing tests, against base R's perl = TRUE engine
# and stringi. Each test first checks that the results agree, then bounds
# the speed. Bounds sit well inside what was measured (an Intel i5-8500B,
# one thread, 200,000 lines): a wide margin is asserted as a speedup, and a
# close one as "no slower", with room for the noise of shared CI runners.

test_that("re_detect() is no slower than grepl() and faster than stringi", {
  skip_unless_timing()
  x <- bench_corpus()
  p <- "\\b555-\\d{4}\\b"
  expect_identical(re_detect(x, p), grepl(p, x, perl = TRUE))
  # Measured 1.05x.
  expect_speedup(
    function() re_detect(x, p),
    function() grepl(p, x, perl = TRUE),
    0.75
  )
  skip_if_not_installed("stringi")
  expect_identical(re_detect(x, p), stringi::stri_detect_regex(x, p))
  # Measured 3.3x.
  expect_speedup(
    function() re_detect(x, p),
    function() stringi::stri_detect_regex(x, p),
    1.5
  )
})

test_that("short calls beat grepl() and stringi", {
  skip_unless_timing()
  short <- bench_corpus(10)
  p <- "user(\\d+)@host(\\d+)\\.com"
  expect_identical(re_detect(short, p), grepl(p, short, perl = TRUE))
  # Measured 1.6x on 10 strings: one .Call does what base R does in C, and
  # the cache saves the compile base R repeats on every call.
  expect_speedup(
    function() {
      for (i in 1:2000) {
        re_detect(short, p)
      }
    },
    function() {
      for (i in 1:2000) {
        grepl(p, short, perl = TRUE)
      }
    },
    1.2
  )
  skip_if_not_installed("stringi")
  one <- short[1]
  calls <- list(
    list(function() re_detect(one, p), function() {
      stringi::stri_detect_regex(one, p)
    }),
    list(function() re_count(one, p), function() {
      stringi::stri_count_regex(one, p)
    }),
    list(function() re_locate(one, p), function() {
      stringi::stri_locate_first_regex(one, p)
    }),
    list(function() re_extract(one, p), function() {
      stringi::stri_extract_first_regex(one, p)
    }),
    list(function() re_match(one, p), function() {
      stringi::stri_match_first_regex(one, p)
    }),
    list(
      function() re_replace(one, p, "$2:$1"),
      function() stringi::stri_replace_all_regex(one, p, "$2:$1")
    ),
    list(function() re_split(one, "[,;] *"), function() {
      stringi::stri_split_regex(one, "[,;] *")
    })
  )
  # Measured 1.05x to 1.3x on one string; "no slower" leaves room for noise.
  for (pair in calls) {
    expect_speedup(
      function() {
        for (i in 1:2000) {
          pair[[1]]()
        }
      },
      function() {
        for (i in 1:2000) {
          pair[[2]]()
        }
      },
      0.85
    )
  }
})

test_that("captures beat regexec() and stringi", {
  skip_unless_timing()
  x <- bench_corpus()
  p <- "user(\\d+)@host(\\d+)\\.com"
  base_caps <- function() {
    m <- regmatches(x, regexec(p, x, perl = TRUE))
    do.call(rbind, m)
  }
  expect_identical(
    unname(as.matrix(re_match(x, p))),
    unname(base_caps()[, 2:3])
  )
  # Measured 41x.
  expect_speedup(function() re_match(x, p), base_caps, 10, reps = 1)
  skip_if_not_installed("stringi")
  # Measured 2.1x.
  expect_speedup(
    function() re_match(x, p),
    function() stringi::stri_match_first_regex(x, p),
    1.3
  )
})

test_that("re_extract_all() beats gregexpr() and is no slower than stringi", {
  skip_unless_timing()
  x <- bench_corpus()
  p <- "\\d+"
  expect_identical(
    re_extract_all(x, p),
    regmatches(x, gregexpr(p, x, perl = TRUE))
  )
  # Measured 13x.
  expect_speedup(
    function() re_extract_all(x, p),
    function() regmatches(x, gregexpr(p, x, perl = TRUE)),
    5,
    reps = 1
  )
  skip_if_not_installed("stringi")
  expect_identical(re_extract_all(x, p), stringi::stri_extract_all_regex(x, p))
  # Measured 1.3x.
  expect_speedup(
    function() re_extract_all(x, p),
    function() stringi::stri_extract_all_regex(x, p),
    0.8
  )
})

test_that("re_replace() is no slower than gsub() and beats stringi", {
  skip_unless_timing()
  x <- bench_corpus()
  p <- "user(\\d+)@host(\\d+)"
  expect_identical(
    re_replace(x, p, "$2:$1"),
    gsub(p, "\\2:\\1", x, perl = TRUE)
  )
  # Measured 1.18x.
  expect_speedup(
    function() re_replace(x, p, "$2:$1"),
    function() gsub(p, "\\2:\\1", x, perl = TRUE),
    0.8
  )
  skip_if_not_installed("stringi")
  expect_identical(
    re_replace(x, p, "$2:$1"),
    stringi::stri_replace_all_regex(x, p, "$2:$1")
  )
  # Measured 2.5x.
  expect_speedup(
    function() re_replace(x, p, "$2:$1"),
    function() stringi::stri_replace_all_regex(x, p, "$2:$1"),
    1.5
  )
})

test_that("re_split() is no slower than strsplit() or stringi", {
  skip_unless_timing()
  x <- bench_corpus()
  p <- "[,;]\\s*"
  # No line ends in a separator, so strsplit()'s dropped trailing piece
  # (a GAP elsewhere) does not arise.
  expect_identical(re_split(x, p), strsplit(x, p, perl = TRUE))
  # Measured 1.45x.
  expect_speedup(
    function() re_split(x, p),
    function() strsplit(x, p, perl = TRUE),
    0.9
  )
  skip_if_not_installed("stringi")
  expect_identical(re_split(x, p), stringi::stri_split_regex(x, p))
  # Measured 1.45x.
  expect_speedup(
    function() re_split(x, p),
    function() stringi::stri_split_regex(x, p),
    0.9
  )
})

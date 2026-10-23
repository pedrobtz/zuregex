# A character vector with one pattern string takes the fast path, a single
# .Call that compiles, matches and builds the result; a vector of patterns
# or an `re` object takes the general path. Both must agree.

test_that("the fast path and the R path give identical results", {
  x <- c(parity_subjects(), NA, "")
  paths <- every_path(x, "(?<w>[a-z]+)(\\d)?")
  fast <- every_path_result(x, paths$fast)
  expect_identical(every_path_result(x, paths$vector), fast)
  expect_identical(every_path_result(x, paths$re), fast)
})

test_that("bytes-marked and latin1 subjects agree on every path", {
  # The bytes scan in zuregex_prepare_c() was never reached (#80).
  b <- "\u00e9"
  Encoding(b) <- "bytes"
  latin1 <- iconv("caf\u00e9 ab1", "UTF-8", "latin1")
  for (x in list(c(b, "ab1", NA), c(latin1, "xy2"))) {
    paths <- every_path(x, "(?<w>[a-z]+)(\\d)?")
    fast <- every_path_result(x, paths$fast)
    expect_identical(every_path_result(x, paths$vector), fast)
    expect_identical(every_path_result(x, paths$re), fast)
  }
  expect_identical(
    re_extract(c(b, "ab"), "(?<n>^..$)", group = "n"),
    c(b, "ab")
  )
})

test_that("the fast path raises classed compile errors with their offset", {
  err <- expect_error(re_detect("abc", "a(b"), class = "zuregex_error_compile")
  expect_identical(err$offset, 4L)
  expect_identical(err$pattern, "a(b")
  expect_error(re_replace("abc", "[", "x"), class = "zuregex_error_compile")
  expect_error(re_extract_all("abc", "a{2,1}"), class = "zuregex_error_compile")
})

test_that("inputs the fast path declines still work", {
  # A pattern in another encoding is translated on the R path.
  latin1 <- iconv("caf\u00e9", "UTF-8", "latin1")
  expect_identical(Encoding(latin1), "latin1")
  expect_true(re_detect("un caf\u00e9", latin1))
  # An NA pattern, raw subjects and bytes-marked subjects.
  expect_identical(re_detect(c("a", "b"), NA_character_), c(NA, NA))
  expect_true(re_detect(as.raw(c(0x61, 0x62)), "ab"))
  b <- "\u00e9"
  Encoding(b) <- "bytes"
  expect_true(re_detect(b, "^..$"))
  # A bytes-marked pattern: matched as bytes.
  pb <- "\u00e9"
  Encoding(pb) <- "bytes"
  expect_true(re_detect(b, pb))
})

test_that("groups that share a name under J share a column on every path", {
  # The fast path gave each group its own column (#76).
  x <- c("x", "y")
  for (p in c("(?<a>x)|(?<a>y)", "(?J)(?<a>x)|(?<a>y)")) {
    flags <- if (startsWith(p, "(?J)")) "" else "J"
    want <- data.frame(a = c("x", "y"))
    expect_identical(re_match(x, p, flags = flags), want)
    expect_identical(
      re_match(x, re_compile(p, flags = flags)),
      want
    )
    all <- re_match_all(x, p, flags = flags)
    expect_named(all, c("element", "match", "a"))
    expect_identical(all$a, c("x", "y"))
  }
})

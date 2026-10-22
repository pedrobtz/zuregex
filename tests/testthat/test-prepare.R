# One pattern string takes the single-.Call path in prepare(); a vector of
# patterns or an `re` object takes the R path. Both must agree.

test_that("the fast path and the R path give identical results", {
  x <- c(parity_subjects(), NA, "")
  pattern <- "(?<w>[a-z]+)(\\d)?"
  paths <- list(
    fast = pattern,
    vector = rep(pattern, length(x)),
    re = re_compile(pattern)
  )
  run <- function(p) {
    list(
      re_detect(x, p),
      re_count(x, p),
      re_locate(x, p),
      re_locate_all(x, p),
      re_extract(x, p, group = "w"),
      re_extract_all(x, p),
      re_match(x, p),
      re_match_all(x, p),
      re_replace(x, p, "<${w}>"),
      re_replace(x, p, function(m) toupper(m[["0"]])),
      re_expand(x, p, "[$1]"),
      re_split(x, p, keep_groups = TRUE)
    )
  }
  fast <- run(paths$fast)
  expect_identical(run(paths$vector), fast)
  expect_identical(run(paths$re), fast)
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

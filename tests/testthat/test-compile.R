test_that("re_compile() returns an re vector, one element per pattern", {
  re <- re_compile(c("a+", "b", NA))
  expect_s3_class(re, "re")
  expect_length(re, 3L)
  expect_identical(as.character(re), c("a+", "b", NA))
})

test_that("every flag letter round-trips into the options re_info() reads", {
  # re_info()$flags is rebuilt from PCRE2's own record of the options
  # (PCRE2_INFO_ARGOPTIONS and PCRE2_INFO_EXTRAOPTIONS), so this checks the
  # mapping of design section 5.1 end to end.
  letters <- c(
    "i",
    "m",
    "s",
    "x",
    "xx",
    "n",
    "U",
    "J",
    "u",
    "r",
    "aD",
    "aS",
    "aW",
    "aT",
    "aP"
  )
  for (flag in letters) {
    expect_identical(re_info(re_compile("a", flags = flag))$flags, flag)
  }
})

test_that("flags combine and are reported in a canonical order", {
  expect_identical(re_info(re_compile("a", flags = "smi"))$flags, "ims")
  expect_identical(
    re_info(re_compile("a", flags = "a"))$flags,
    "aDaSaWaTaP"
  )
  expect_identical(re_info(re_compile("a", flags = "xxi"))$flags, "ixx")
})

test_that("unknown flag letters are a zuregex_error_flags", {
  expect_error(re_compile("a", flags = "q"), class = "zuregex_error_flags")
  expect_error(re_compile("a", flags = "aQ"), class = "zuregex_error_flags")
  expect_error(re_compile("a", flags = "i q"), class = "zuregex_error_flags")
  expect_error(re_compile("a", flags = "xxx"), class = "zuregex_error_flags")
  expect_error(re_compile("a", flags = "q"), class = "zuregex_error")
})

test_that("literal patterns accept only the flags PCRE2 allows with them", {
  re <- re_compile("a.b", flags = "ir", literal = TRUE)
  expect_identical(re_info(re)$flags, "ir")
  expect_true(re_info(re)$literal)
  expect_error(
    re_compile("a.b", flags = "m", literal = TRUE),
    class = "zuregex_error_flags"
  )
})

test_that("the js dialect sets node-pcre2's options and pcre sets none", {
  pcre <- re_info(re_compile("a"))
  js <- re_info(re_compile("a", dialect = "js"))
  expect_identical(pcre$dialect, "pcre")
  expect_identical(js$dialect, "js")
  expect_identical(pcre$flags, "")
  expect_identical(js$flags, "")
  # \u escapes are JavaScript syntax: an error in the pcre dialect.
  expect_error(re_compile("\\u0041"), class = "zuregex_error_compile")
  expect_s3_class(re_compile("\\u0041", dialect = "js"), "re")
  # A literal pattern drops the dialect's syntax options instead of failing.
  expect_s3_class(re_compile("\\u0041", dialect = "js", literal = TRUE), "re")
})

test_that("re_info() describes groups, names and lengths", {
  info <- re_info(re_compile("(?<year>\\d{4})-(\\d{2})(?<day>x)?\\1"))
  expect_identical(info$groups, 3L)
  expect_identical(info$group_names, list(c("year", "", "day")))
  expect_true(info$backrefs)
  # 4 + 1 + 2, the optional group adds nothing, and \1 repeats group 1.
  expect_identical(info$min_length, 11L)
  expect_identical(info$pcre2_version, "10.48")
  expect_false(re_info(re_compile("a"))$backrefs)
})

test_that("re_info() reports the literal prefix every match starts with", {
  prefix <- function(...) re_info(re_compile(...))$prefix
  expect_identical(prefix("abc"), "abc")
  expect_identical(prefix("abc+"), "ab")
  expect_identical(prefix("ab?c"), "a")
  expect_identical(prefix("ab{2}"), "a")
  expect_identical(prefix("abc|abd"), "")
  expect_identical(prefix("a(b|c)"), "a")
  expect_identical(prefix("a\\.b\\d"), "a.b")
  expect_identical(prefix("^abc"), "")
  expect_identical(prefix("abc", flags = "i"), "")
  expect_identical(prefix("a b", flags = "x"), "")
  expect_identical(prefix("a.b+", literal = TRUE), "a.b+")
  expect_identical(prefix("\u00e9t\u00e9s"), "\u00e9t\u00e9s")
  expect_identical(prefix("(?i)abc"), "")
})

test_that("re_info() is a data frame with one row per pattern", {
  info <- re_info(re_compile(c("a", "(b)", NA)))
  expect_s3_class(info, "data.frame")
  expect_identical(nrow(info), 3L)
  expect_identical(info$groups, c(0L, 1L, NA))
  expect_identical(info$pattern, c("a", "(b)", NA))
})

test_that("jit = FALSE compiles for the interpreter", {
  expect_false(re_info(re_compile("a+", jit = FALSE))$jit)
  skip_if_not(zuregex_info()$jit_usable)
  expect_true(re_info(re_compile("a+"))$jit)
})

test_that("re_compile() checks its arguments", {
  expect_error(re_compile(1), class = "zuregex_error_argument")
  expect_error(
    re_compile("a", flags = c("i", "m")),
    class = "zuregex_error_argument"
  )
  expect_error(re_compile("a", flags = NA), class = "zuregex_error_argument")
  expect_error(re_compile("a", literal = NA), class = "zuregex_error_argument")
  expect_error(re_compile("a", jit = "yes"), class = "zuregex_error_argument")
  expect_error(
    re_compile("a", dialect = "perl"),
    class = "zuregex_error_argument"
  )
  expect_error(re_info("a"), class = "zuregex_error_argument")
  bytes_flags <- "i\xff"
  Encoding(bytes_flags) <- "bytes"
  expect_error(
    re_compile("a", flags = bytes_flags),
    class = "zuregex_error_argument"
  )
})

test_that("patterns in other encodings are compiled as UTF-8", {
  latin1 <- iconv("caf\u00e9", "UTF-8", "latin1")
  expect_identical(Encoding(latin1), "latin1")
  re <- re_compile(latin1)
  expect_identical(as.character(re), "caf\u00e9")
  expect_identical(re_info(re)$min_length, 4L)
})

test_that("\\C is refused in UTF mode and allowed on bytes", {
  # One byte of a UTF-8 subject can end inside a character, which breaks
  # every later search and every string a verb returns (#75).
  expect_error(re_compile("\\C"), class = "zuregex_error_compile")
  expect_error(
    re_extract_all("é", "\\C"),
    class = "zuregex_error_compile"
  )
  expect_identical(re_count(charToRaw("é"), "\\C"), 2L)
})

test_that("compile errors are classed on every route into the cache", {
  # A named group always goes through prepare(); raw subjects through the
  # one-string branch of patterns() (#97).
  err <- expect_error(
    re_extract("a", "(?<n>a", group = "n"),
    class = "zuregex_error_compile"
  )
  expect_identical(err$offset, 7L)
  err <- expect_error(
    re_detect(charToRaw("a"), "a("),
    class = "zuregex_error_compile"
  )
  expect_identical(err$offset, 3L)
})

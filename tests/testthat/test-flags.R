# `flags` and `literal` on every verb: base R's ignore.case and fixed.

test_that("flags = \"i\" matches base R's ignore.case = TRUE", {
  x <- c("Apple pie", "BANANA", "cherry", NA, "")
  p <- "an|ap"
  expect_identical(
    re_detect(x, p, flags = "i"),
    ifelse(is.na(x), NA, grepl(p, x, ignore.case = TRUE, perl = TRUE))
  )
  ok <- !is.na(x)
  expect_identical(
    re_extract_all(x[ok], p, flags = "i"),
    regmatches(x[ok], gregexpr(p, x[ok], ignore.case = TRUE, perl = TRUE))
  )
  expect_identical(
    re_replace(x[ok], p, "-", flags = "i"),
    gsub(p, "-", x[ok], ignore.case = TRUE, perl = TRUE)
  )
  expect_identical(
    re_count(x[ok], p, flags = "i"),
    lengths(regmatches(
      x[ok],
      gregexpr(p, x[ok], ignore.case = TRUE, perl = TRUE)
    ))
  )
})

test_that("literal = TRUE matches base R's fixed = TRUE", {
  x <- c("a.b.c", "a+b", "(x)", "no dots", "")
  for (p in c(".", "+", "(x)")) {
    expect_identical(re_detect(x, p, literal = TRUE), grepl(p, x, fixed = TRUE))
    expect_identical(
      re_replace(x, p, "-", literal = TRUE),
      gsub(p, "-", x, fixed = TRUE)
    )
    expect_identical(
      re_extract_all(x, p, literal = TRUE),
      regmatches(x, gregexpr(p, x, fixed = TRUE))
    )
    expect_identical(
      re_locate(x, p, literal = TRUE)[, "start"],
      ifelse(regexpr(p, x, fixed = TRUE) > 0, regexpr(p, x, fixed = TRUE), NA)
    )
  }
  # GAP: strsplit() drops a trailing empty piece; re_split() keeps it.
  expect_identical(
    re_split("a.b.c", ".", literal = TRUE),
    list(c("a", "b", "c"))
  )
  expect_identical(re_count("a.b.c", ".", literal = TRUE), 2L)
  # A literal pattern ignores case with "i".
  expect_true(re_detect("A.B", "a.b", flags = "i", literal = TRUE))
})

test_that("a pattern string, a vector of them and an re object agree", {
  x <- c(parity_subjects(), NA)
  p <- "(?<w>[a-z])(\\d)?"
  for (opts in list(list("i", FALSE), list("ims", FALSE), list("i", TRUE))) {
    flags <- opts[[1]]
    literal <- opts[[2]]
    run <- function(pattern, ...) {
      list(
        re_detect(x, pattern, ...),
        re_count(x, pattern, ...),
        re_locate(x, pattern, ...),
        re_locate_all(x, pattern, ...),
        re_extract(x, pattern, ...),
        re_extract_all(x, pattern, ...),
        re_replace(x, pattern, "<$0>", ...),
        re_expand(x, pattern, "[$0]", ...),
        re_split(x, pattern, ...)
      )
    }
    fast <- run(p, flags = flags, literal = literal)
    vector <- run(rep(p, length(x)), flags = flags, literal = literal)
    re <- run(re_compile(p, flags = flags, literal = literal))
    expect_identical(vector, fast)
    expect_identical(re, fast)
  }
})

test_that("re_match() and replacement functions take flags", {
  x <- c("Key=1", "key=22", "none")
  out <- re_match(x, "(?<k>key)=(?<v>\\d+)", flags = "i")
  expect_identical(out$k, c("Key", "key", NA))
  expect_identical(out$v, c("1", "22", NA))
  all <- re_match_all("A1 a2", "(a)(\\d)", flags = "i")
  expect_identical(all[["1"]], c("A", "a"))
  expect_identical(
    re_replace(x, "key", function(m) toupper(m[["0"]]), flags = "i"),
    c("KEY=1", "KEY=22", "none")
  )
})

test_that("other flags work on the verbs", {
  expect_identical(
    re_extract_all("a\nb", "^\\w", flags = "m"),
    list(c("a", "b"))
  )
  expect_true(re_detect("a\nb", "a.b", flags = "s"))
  expect_false(re_detect("a\nb", "a.b"))
  expect_true(re_detect("ab", "a b # comment", flags = "x"))
  # Raw subjects, matched as bytes, take flags too.
  expect_true(re_detect(charToRaw("ABC"), "abc", flags = "i"))
})

test_that("the cache keeps the same pattern with different flags apart", {
  local_cache(16L)
  expect_false(re_detect("A", "a"))
  expect_true(re_detect("A", "a", flags = "i"))
  expect_false(re_detect("A", "a"))
  expect_true(re_detect("x.y", "x.y", literal = TRUE))
  expect_false(re_detect("xzy", "x.y", literal = TRUE))
  expect_true(re_detect("xzy", "x.y"))
})

test_that("bad flags and literal are classed errors on both paths", {
  # One pattern string (fast path) and a vector of patterns (R path).
  for (p in list("a", c("a", "b"))) {
    x <- rep("a", length(p))
    err <- expect_error(
      re_detect(x, p, flags = "q"),
      class = "zuregex_error_flags"
    )
    expect_identical(err$position, 1L)
    expect_error(re_detect(x, p, flags = "ii"), class = "zuregex_error_flags")
    expect_error(
      re_detect(x, p, flags = "m", literal = TRUE),
      class = "zuregex_error_flags"
    )
    expect_error(
      re_replace(x, p, "-", flags = "q"),
      class = "zuregex_error_flags"
    )
  }
  expect_error(
    re_detect("a", "a", flags = NA),
    class = "zuregex_error_argument"
  )
  expect_error(
    re_detect("a", "a", flags = c("i", "m")),
    class = "zuregex_error_argument"
  )
  expect_error(
    re_detect("a", "a", literal = NA),
    class = "zuregex_error_argument"
  )
  # A mark on ASCII is dropped, so the flags must be non-ASCII to carry it.
  bytes_flags <- "\u00e9"
  Encoding(bytes_flags) <- "bytes"
  expect_error(
    re_detect("a", "a", flags = bytes_flags),
    class = "zuregex_error_argument"
  )
})

test_that("an re object takes neither flags nor literal", {
  re <- re_compile("a", flags = "i")
  expect_true(re_detect("A", re))
  expect_error(
    re_detect("A", re, flags = "i"),
    class = "zuregex_error_argument"
  )
  expect_error(
    re_extract_all("A", re, literal = TRUE),
    class = "zuregex_error_argument"
  )
  expect_error(
    re_replace("A", re, "-", flags = ""),
    class = "zuregex_error_argument"
  )
})

test_that("flag errors name the flags in their message", {
  expect_snapshot(re_detect("a", "a", flags = "iq"), error = TRUE)
  expect_snapshot(
    re_detect("a", c("a"), flags = "m", literal = TRUE),
    error = TRUE
  )
})

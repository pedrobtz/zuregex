test_that("re_match() equals stringr::str_match() on the parity corpus", {
  skip_if_not_installed("stringr")
  x <- parity_subjects()
  for (p in capture_patterns()) {
    ours <- as.matrix(re_match(x, p))
    theirs <- stringr::str_match(x, p)[, -1, drop = FALSE]
    dimnames(ours) <- dimnames(theirs) <- NULL
    expect_identical(ours, theirs, label = p)
  }
})

test_that("re_match() equals utils::strcapture() for typed captures", {
  x <- c("x=1; y=22", "a=7", "none", "b=", "c=99999")
  proto <- data.frame(key = character(), value = integer())
  ours <- re_match(x, "(\\w+)=(\\d+)", proto = proto)
  theirs <- utils::strcapture("(\\w+)=(\\d+)", x, proto, perl = TRUE)
  expect_identical(ours, theirs)
  dates <- c("2026-10-21", "1999-12-31", "nope")
  proto <- data.frame(y = 0L, m = 0L, d = 0L)
  expect_identical(
    re_match(dates, "(\\d{4})-(\\d{2})-(\\d{2})", proto = proto),
    utils::strcapture("(\\d{4})-(\\d{2})-(\\d{2})", dates, proto, perl = TRUE)
  )
  num <- re_match("pi is 3.14", "(\\d+\\.\\d+)", proto = list(value = 0))
  expect_identical(num$value, 3.14)
})

test_that("an unset group is NA, not \"\"", {
  # GAP: regmatches() and so strcapture() give "" for a group that did not
  # take part in the match; stringr and zuregex give NA.
  out <- re_match("foo", "(foo)(\\d+)?")
  expect_identical(out[["2"]], NA_character_)
  base <- regmatches("foo", regexec("(foo)(\\d+)?", "foo", perl = TRUE))[[1]]
  expect_identical(base[[3]], "")
  expect_identical(
    re_match("foo", "(foo)(\\d+)?", proto = list(a = "", b = 0L))$b,
    NA_integer_
  )
})

test_that("re_extract() equals regmatches() and stringr::str_extract()", {
  x <- parity_subjects()
  for (p in c(parity_patterns(), capture_patterns())) {
    ours <- re_extract(x, p)
    m <- regexpr(p, x, perl = TRUE)
    expect_identical(ours[!is.na(ours)], regmatches(x, m), label = p)
    if (requireNamespace("stringr", quietly = TRUE)) {
      expect_identical(ours, stringr::str_extract(x, p), label = p)
    }
  }
})

test_that("re_extract_all() equals stringr::str_extract_all()", {
  skip_if_not_installed("stringr")
  x <- c(parity_subjects(), NA)
  nonempty <- setdiff(parity_patterns(), c("a*", "^$", "a?b", "^\\s+|\\s+$"))
  for (p in c(nonempty, capture_patterns())) {
    expect_identical(
      re_extract_all(x, p),
      stringr::str_extract_all(x, p),
      label = p
    )
  }
})

test_that("re_extract() takes a group by number or name", {
  x <- c("2026-10-21", "x")
  p <- "(?<year>\\d{4})-(\\d{2})"
  expect_identical(re_extract(x, p, group = "year"), c("2026", NA))
  expect_identical(re_extract(x, p, group = 2), c("10", NA))
  expect_identical(re_extract(x, p, group = 0), c("2026-10", NA))
  expect_identical(
    re_extract_all("1-2 3-4", "(\\d)-(\\d)", group = 2),
    list(c("2", "4"))
  )
  expect_identical(stringr::str_match(x, p)[, 3], re_extract(x, p, group = 2))
})

test_that("an unknown group is a zuregex_error_group", {
  expect_error(re_extract("a", "(a)", group = 2), class = "zuregex_error_group")
  expect_error(
    re_extract("a", "(a)", group = "nope"),
    class = "zuregex_error_group"
  )
  expect_error(
    re_extract("a", "(a)", group = -1),
    class = "zuregex_error_argument"
  )
  expect_error(
    re_extract("a", "(a)", group = c(1, 2)),
    class = "zuregex_error_argument"
  )
  expect_error(
    re_extract("a", "(a)", group = NA),
    class = "zuregex_error_argument"
  )
})

test_that("a group some per-element patterns lack is NA for those", {
  x <- c("2026-10", "10/2026")
  p <- c("(?<y>\\d{4})-(?<m>\\d{2})", "(?<m>\\d{2})/\\d{4}")
  expect_identical(re_extract(x, p, group = "y"), c("2026", NA))
  expect_identical(re_extract(x, p, group = "m"), c("10", "10"))
  expect_identical(
    re_extract(c("ab", "a"), c("(a)(b)", "(a)"), group = 2),
    c("b", NA)
  )
  expect_identical(
    re_extract_all(c("ab", "a"), c("(a)(b)", "(a)"), group = 2),
    list("b", NA_character_)
  )
})

test_that("re_match() columns are named groups and group numbers", {
  out <- re_match("2026-10-21", "(?<year>\\d{4})-(\\d{2})-(?<day>\\d{2})")
  expect_named(out, c("year", "2", "day"))
  expect_s3_class(out, "data.frame")
  expect_identical(nrow(re_match(character(), "(a)")), 0L)
  expect_identical(ncol(re_match("a", "a")), 0L)
  expect_identical(nrow(re_match(c("a", "b"), "a")), 2L)
})

test_that("differing patterns produce the documented column union", {
  x <- c("a1", "b2", "c3", "d4")
  p <- c(
    "(?<letter>[a-z])(?<digit>\\d)", # named
    "(?<digit>\\d)", # a name shared with the first
    "(x)?(c)", # unnamed: columns "1" and "2"
    "(d)(?<letter>\\d)" # unnamed first, then a name in another position
  )
  out <- re_match(x, p)
  expect_named(out, c("letter", "digit", "1", "2"))
  expect_identical(out$letter, c("a", NA, NA, "4"))
  expect_identical(out$digit, c("1", "2", NA, NA))
  expect_identical(out[["1"]], c(NA, NA, NA, "d"))
  expect_identical(out[["2"]], c(NA, NA, "c", NA))
  # Each row equals the single-pattern call, read through the union.
  for (i in seq_along(x)) {
    single <- re_match(x[[i]], p[[i]])
    expect_identical(
      as.list(out[i, names(single), drop = FALSE]),
      as.list(single)
    )
  }
})

test_that("re_match_all() equals stringr::str_match_all()", {
  skip_if_not_installed("stringr")
  x <- parity_subjects()
  for (p in capture_patterns()) {
    ours <- re_match_all(x, p)
    theirs <- stringr::str_match_all(x, p)
    for (i in seq_along(x)) {
      rows <- ours[ours$element == i, -(1:2), drop = FALSE]
      expected <- theirs[[i]][, -1, drop = FALSE]
      got <- as.matrix(rows)
      dimnames(got) <- dimnames(expected) <- NULL
      if (nrow(expected) == 0L) {
        expect_identical(nrow(got), 0L, label = paste(p, i))
      } else {
        expect_identical(got, expected, label = paste(p, i))
      }
    }
  }
})

test_that("re_match_all() numbers matches and marks NA input", {
  out <- re_match_all(c("a1b2", NA, "z"), "([a-z])(\\d)")
  expect_identical(out$element, c(1L, 1L, 2L))
  expect_identical(out$match, c(1L, 2L, NA))
  expect_identical(out[["1"]], c("a", "b", NA))
  expect_identical(nrow(re_match_all("a1b2", "([a-z])(\\d)", n = 1)), 1L)
  expect_identical(nrow(re_match_all("a1b2", "([a-z])(\\d)", n = 0)), 0L)
  expect_error(
    re_match_all("a", "(a)", n = -1),
    class = "zuregex_error_argument"
  )
})

test_that("strings come back in UTF-8, or as bytes from bytes", {
  latin1 <- iconv("café au lait", "UTF-8", "latin1")
  got <- re_extract(latin1, "caf.")
  expect_identical(got, "café")
  expect_identical(Encoding(got), "UTF-8")
  raw <- re_extract(charToRaw("café"), "caf..")
  expect_identical(Encoding(raw), "bytes")
  expect_identical(charToRaw(raw), charToRaw("café"))
  expect_identical(Encoding(re_extract(charToRaw("abc"), "b")), "unknown")
})

test_that("proto is checked against the groups", {
  expect_error(
    re_match("a1", "([a-z])(\\d)", proto = list(a = "")),
    class = "zuregex_error_argument"
  )
})

test_that("re_match() is at least 10 times faster than strcapture()", {
  skip_unless_timing()
  withr::local_seed(1)
  n <- 1e5
  x <- sprintf(
    "id=%d user=%s score=%0.2f",
    sample.int(1e6, n),
    vapply(
      seq_len(n),
      function(i) paste(sample(letters, 6), collapse = ""),
      ""
    ),
    stats::runif(n, 0, 100)
  )
  p <- "id=(\\d+) user=(\\w+) score=([\\d.]+)"
  proto <- data.frame(id = 0L, user = "", score = 0)
  ours <- system.time(a <- re_match(x, p, proto = proto))[["elapsed"]]
  theirs <- system.time(b <- utils::strcapture(p, x, proto, perl = TRUE))[[
    "elapsed"
  ]]
  expect_identical(a, b)
  expect_gt(theirs / ours, 10)
})

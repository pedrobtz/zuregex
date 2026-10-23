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
  skip_if_not_installed("stringr")
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
  latin1 <- iconv("caf\u00e9 au lait", "UTF-8", "latin1")
  got <- re_extract(latin1, "caf.")
  expect_identical(got, "caf\u00e9")
  expect_identical(Encoding(got), "UTF-8")
  raw <- re_extract(charToRaw("caf\u00e9"), "caf..")
  expect_identical(Encoding(raw), "bytes")
  expect_identical(charToRaw(raw), charToRaw("caf\u00e9"))
  expect_identical(Encoding(re_extract(charToRaw("abc"), "b")), "unknown")
})

test_that("proto is checked against the groups", {
  expect_error(
    re_match("a1", "([a-z])(\\d)", proto = list(a = "")),
    class = "zuregex_error_argument"
  )
})

test_that("re_match() is at least 5 times faster than strcapture()", {
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
  expect_identical(
    re_match(x, p, proto = proto),
    utils::strcapture(p, x, proto, perl = TRUE)
  )
  # Design section 10 hoped for 10x. Measured 21x on an Intel Mac and 7.9x
  # to 8.3x on the arm64 macOS runner (GAP there), so the bound is 5x.
  expect_speedup(
    function() re_match(x, p, proto = proto),
    function() utils::strcapture(p, x, proto, perl = TRUE),
    5,
    reps = 1
  )
})

test_that("re_extract_all(n =) limits the matches per element", {
  x <- c("a1b2c3", NA, "none")
  expect_identical(
    re_extract_all(x, "\\d", n = 0),
    list(character(), NA_character_, character())
  )
  expect_identical(
    re_extract_all(x, "\\d", n = 1),
    list("1", NA_character_, character())
  )
  expect_identical(re_extract_all(x, "\\d", n = Inf), re_extract_all(x, "\\d"))
  for (bad in list(-1, 1.5, NA, "2")) {
    expect_error(
      re_extract_all(x, "\\d", n = bad),
      class = "zuregex_error_argument"
    )
  }
})

test_that("groups that share a name give the first one that took part", {
  # PCRE2's own rule for ${name}, applied to every verb (the J flag).
  re <- re_compile("(?<a>x)|(?<a>y)", flags = "J")
  x <- c("x", "y", "z")
  expect_identical(re_match(x, re)$a, c("x", "y", NA))
  expect_identical(re_extract(x, re, group = "a"), c("x", "y", NA))
  expect_identical(
    re_extract_all("xyx", re, group = "a"),
    list(c("x", "y", "x"))
  )
  expect_identical(re_match_all("xy", re)$a, c("x", "y"))
  expect_identical(
    re_replace(x, re, function(m) toupper(m$a)),
    c("X", "Y", "z")
  )
  expect_identical(re_replace(x, re, "<${a}>"), c("<x>", "<y>", "z"))
})

test_that("text with a NUL byte is a classed error, not R's", {
  x <- as.raw(c(0x61, 0x00, 0x62))
  expect_error(re_extract(x, "a.b"), class = "zuregex_error_match")
  expect_error(re_match(x, "(a.)b"), class = "zuregex_error_match")
  expect_error(re_split(x, "b"), class = "zuregex_error_match")
  expect_error(re_replace(x, "a", "z"), class = "zuregex_error_match")
  # Matches that do not include the NUL are fine.
  expect_identical(re_extract(x, "a"), "a")
  expect_identical(re_extract_all(x, "[ab]"), list(c("a", "b")))
})

test_that("a shared group name is NA when none of its groups took part", {
  # The fallback when no group with the name is set (#97).
  p <- "(?<a>x)|(?<a>y)|z"
  expect_identical(re_match("z", p, flags = "J")$a, NA_character_)
  expect_identical(re_extract("z", p, group = "a", flags = "J"), NA_character_)
})

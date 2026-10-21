test_that("re_detect() equals grepl(perl = TRUE) on the parity corpus", {
  x <- parity_subjects()
  for (p in parity_patterns()) {
    expect_identical(re_detect(x, p), grepl(p, x, perl = TRUE), label = p)
  }
})

test_that("re_detect() equals stringr::str_detect() on the parity corpus", {
  skip_if_not_installed("stringr")
  x <- parity_subjects()
  for (p in parity_patterns()) {
    expect_identical(re_detect(x, p), stringr::str_detect(x, p), label = p)
  }
})

test_that("re_count() equals stringr::str_count() on the parity corpus", {
  skip_if_not_installed("stringr")
  x <- parity_subjects()
  # Patterns that can match the empty string are compared in the GAP test
  # below; ICU and PCRE2 step past an empty match differently.
  nonempty <- setdiff(
    parity_patterns(),
    c("a*", "^$", "a?b", "^\\s+|\\s+$")
  )
  for (p in nonempty) {
    expect_identical(re_count(x, p), stringr::str_count(x, p), label = p)
  }
})

test_that("re_count() counts empty matches as PCRE2 and Python do", {
  # GAP: gregexpr() reports one match of "a*" in "aaa", dropping the empty
  # match at the end. PCRE2's own iteration rule (pcre2_next_match()), like
  # Python's re.findall(), finds "aaa" and then "".
  expect_identical(re_count("aaa", "a*"), 2L)
  expect_identical(lengths(gregexpr("a*", "aaa", perl = TRUE)), 1L)
  # Python: len(re.findall("a*", "abab")) == 5; len(re.findall("", "abc")) == 4
  expect_identical(re_count("abab", "a*"), 5L)
  expect_identical(re_count("abc", ""), 4L)
  expect_identical(re_count("", ""), 1L)
  expect_identical(re_count("\u00e9\u00e9", ""), 3L)
})

test_that("an NA subject gives NA", {
  # GAP: grepl() returns FALSE for an NA subject. NA is what stringr gives,
  # and it does not claim a missing string fails to match.
  expect_identical(re_detect(c("a", NA), "a"), c(TRUE, NA))
  expect_identical(grepl("a", c("a", NA), perl = TRUE), c(TRUE, FALSE))
  expect_identical(re_count(c("a", NA), "a"), c(1L, NA))
  expect_identical(re_detect(NA_character_, "a", negate = TRUE), NA)
})

test_that("\\w, \\d and POSIX classes are ASCII, as in base R", {
  # GAP: ICU, and so stringr, gives \w, \d and [[:alpha:]] Unicode meaning.
  # zuregex follows base R's perl = TRUE (design D2); the `u` flag of
  # re_compile() turns Unicode meaning on.
  x <- c("\u00e9", "\u0663", "a")
  expect_identical(re_detect(x, "^\\w$"), grepl("^\\w$", x, perl = TRUE))
  expect_identical(re_detect(x, "^\\w$"), c(FALSE, FALSE, TRUE))
  skip_if_not_installed("stringr")
  expect_identical(stringr::str_detect(x, "^\\w$"), c(TRUE, TRUE, TRUE))
  expect_identical(
    re_detect(x, re_compile("^\\w$", flags = "u")),
    c(TRUE, TRUE, TRUE)
  )
})

test_that("anchor = \"start\" and \"full\" hold for every alternative", {
  x <- c("abc", "xabc", "ab", "abcx")
  expect_identical(
    re_detect(x, "abc|ab", anchor = "start"),
    c(TRUE, FALSE, TRUE, TRUE)
  )
  expect_identical(
    re_detect(x, "abc|ab", anchor = "full"),
    c(TRUE, FALSE, TRUE, FALSE)
  )
  # Python: re.fullmatch("a|ab", "ab") matches; a pattern rewritten as
  # ^a|ab$ would not express that.
  expect_true(re_detect("ab", "a|ab", anchor = "full"))
  expect_identical(re_detect(x, "b", anchor = "start"), rep(FALSE, 4))
})

test_that("negate inverts matches but not NA", {
  expect_identical(
    re_detect(c("a", "b", NA), "a", negate = TRUE),
    c(FALSE, TRUE, NA)
  )
})

test_that("pattern has length 1 or length(x); nothing is recycled", {
  x <- c("a1", "b2", "c3", "d4")
  expect_identical(re_detect(x, "\\d"), rep(TRUE, 4))
  expect_identical(
    re_detect(x, c("a", "x", "c", "4")),
    c(TRUE, FALSE, TRUE, TRUE)
  )
  for (bad in list(c("a", "b"), c("a", "b", "c"), rep("a", 5), character())) {
    expect_error(re_detect(x, bad), class = "zuregex_error_length")
    expect_error(re_count(x, bad), class = "zuregex_error_length")
  }
  expect_identical(re_detect(character(), "a"), logical())
  expect_identical(re_count(character(), "a"), integer())
})

test_that("per-element results equal a loop over single-pattern calls", {
  x <- parity_subjects()
  p <- rep_len(parity_patterns(), length(x))
  looped_detect <- vapply(
    seq_along(x),
    function(i) re_detect(x[[i]], p[[i]]),
    TRUE
  )
  looped_count <- vapply(seq_along(x), function(i) re_count(x[[i]], p[[i]]), 1L)
  expect_identical(re_detect(x, p), looped_detect)
  expect_identical(re_count(x, p), looped_count)
  skip_if_not_installed("stringr")
  expect_identical(re_detect(x, p), stringr::str_detect(x, p))
})

test_that("an NA pattern gives NA for its element", {
  expect_identical(re_detect(c("a", "b"), c("a", NA)), c(TRUE, NA))
  expect_identical(re_count(c("a", "b"), c(NA, "b")), c(NA, 1L))
  expect_identical(re_detect("a", NA_character_), NA)
})

test_that("re objects carry flags, dialects and literals into matching", {
  x <- c("HELLO", "a.b", "axb")
  expect_identical(
    re_detect(x, re_compile("hello", flags = "i")),
    c(TRUE, FALSE, FALSE)
  )
  expect_identical(
    re_detect(x, re_compile("a.b", literal = TRUE)),
    c(FALSE, TRUE, FALSE)
  )
  expect_identical(re_detect("A", re_compile("\\u0041", dialect = "js")), TRUE)
  re <- re_compile(c("^H", "\\.", "x"))
  expect_identical(re_detect(x, re), c(TRUE, TRUE, TRUE))
  expect_identical(re_detect(x, re[c(1, 1, 1)]), c(TRUE, FALSE, FALSE))
  expect_error(re_detect(x, re[1:2]), class = "zuregex_error_length")
  expect_identical(re_detect(c("a", "b"), re_compile(c("a", NA))), c(TRUE, NA))
})

test_that("invalid pattern strings raise zuregex_error_compile", {
  err <- expect_error(
    re_detect(c("a", "b"), c("a", "(")),
    class = "zuregex_error_compile"
  )
  expect_identical(err$pattern, "(")
})

test_that("a raw vector matches like the same bytes as a string", {
  x <- c("hello world", "foo123", "", "a.b")
  for (p in c("o", "^h", "\\d+", "\\.", "^$", "l+")) {
    raw_result <- vapply(
      x,
      function(s) re_detect(charToRaw(s), p),
      TRUE,
      USE.NAMES = FALSE
    )
    expect_identical(raw_result, re_detect(x, p), label = p)
    expect_identical(
      re_detect(lapply(x, charToRaw), p),
      re_detect(x, p),
      label = p
    )
    expect_identical(
      re_count(lapply(x, charToRaw), p),
      re_count(x, p),
      label = p
    )
  }
})

test_that("bytes are matched without UTF-8: . is one byte", {
  e <- charToRaw("\u00e9") # two bytes
  expect_true(re_detect(e, "^..$"))
  expect_false(re_detect("\u00e9", "^..$"))
  expect_true(re_detect(as.raw(c(0x61, 0xff, 0x62)), "a\\xffb"))
  expect_identical(re_detect(list(NULL, as.raw(0x61)), "a"), c(NA, TRUE))
  # An re compiled for UTF-8 is recompiled for bytes.
  expect_true(re_detect(e, re_compile("^..$")))
  bytes <- "\u00e9"
  Encoding(bytes) <- "bytes"
  expect_true(re_detect(bytes, "^..$"))
})

test_that("strings in other encodings are translated to UTF-8", {
  latin1 <- iconv(c("caf\u00e9", "na\u00efve"), "UTF-8", "latin1")
  expect_identical(Encoding(latin1), c("latin1", "latin1"))
  expect_identical(re_detect(latin1, "\u00e9$"), c(TRUE, FALSE))
  expect_identical(re_detect(latin1, "^.{4}$"), c(TRUE, FALSE))
})

test_that("invalid UTF-8 is a zuregex_error_utf naming element and byte", {
  bad <- "ab\xffc"
  Encoding(bad) <- "UTF-8"
  err <- expect_error(
    re_detect(c("ok", "fine", bad), "c"),
    class = "zuregex_error_utf"
  )
  expect_s3_class(err, "zuregex_error")
  expect_identical(err$element, 3)
  expect_identical(err$byte, 3)
  expect_error(re_count(bad, "c"), class = "zuregex_error_utf")
  expect_snapshot(re_detect(c("ok", bad), "c"), error = TRUE)
  # An NA pattern means the element is not matched, so not checked either.
  expect_identical(re_detect(c("a", bad), c("a", NA)), c(TRUE, NA))
})

test_that("calls with more patterns than the cache holds leave it alone", {
  local_cache(4L)
  re_compile(c("w", "x", "y", "z"))
  before <- zuregex:::cache_stats()
  x <- paste0("s", 1:10)
  expect_identical(re_detect(x, paste0("s", 1:10, "$")), rep(TRUE, 10))
  expect_identical(stats_delta(before), c(hits = 0, misses = 0, evictions = 0))
  # Within capacity, the call's patterns go through the cache.
  re_detect(x[1:3], c("w", "x", "y"))
  expect_identical(stats_delta(before)[["hits"]], 3)
})

test_that("re_detect() checks its arguments", {
  expect_error(re_detect(1, "a"), class = "zuregex_error_argument")
  expect_error(re_detect(list("a"), "a"), class = "zuregex_error_argument")
  expect_error(re_detect("a", 1), class = "zuregex_error_argument")
  expect_error(
    re_detect("a", "a", anchor = "end"),
    class = "zuregex_error_argument"
  )
  expect_error(
    re_detect("a", "a", negate = NA),
    class = "zuregex_error_argument"
  )
})

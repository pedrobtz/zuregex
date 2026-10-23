test_that("substr() on re_locate() extracts each match", {
  x <- parity_subjects()
  for (p in parity_patterns()) {
    loc <- re_locate(x, p)
    found <- !is.na(loc[, "start"])
    expected <- regmatches(x, regexpr(p, x, perl = TRUE))
    expect_identical(
      substr(x[found], loc[found, "start"], loc[found, "end"]),
      expected,
      label = p
    )
  }
})

test_that("x[start:end] on a raw vector extracts the match", {
  x <- charToRaw("key=value; k2=v2")
  loc <- re_locate(x, "k2=\\w+")
  expect_identical(rawToChar(x[loc[, "start"]:loc[, "end"]]), "k2=v2")
  all <- re_locate_all(x, "\\w+=")
  expect_identical(
    vapply(
      seq_len(nrow(all)),
      function(i) rawToChar(x[all$start[i]:all$end[i]]),
      ""
    ),
    c("key=", "k2=")
  )
})

test_that("re_locate() equals regexpr(perl = TRUE) on the parity corpus", {
  x <- parity_subjects()
  for (p in parity_patterns()) {
    expect_identical(re_locate(x, p), base_locate(x, p), label = p)
  }
})

test_that("re_locate() equals stringr::str_locate() for non-empty matches", {
  skip_if_not_installed("stringr")
  x <- parity_subjects()
  for (p in parity_patterns()) {
    ours <- re_locate(x, p)
    theirs <- stringr::str_locate(x, p)
    nonempty <- !is.na(ours[, "start"]) & ours[, "end"] >= ours[, "start"]
    expect_identical(
      ours[nonempty, , drop = FALSE],
      theirs[nonempty, , drop = FALSE],
      label = p
    )
    # Both agree on which subjects match, except "" (GAP below).
    filled <- x != ""
    expect_identical(
      is.na(ours[filled, "start"]),
      is.na(theirs[filled, "start"]),
      label = p
    )
  }
})

test_that("an empty match at k is start = k, end = k - 1", {
  expect_identical(
    re_locate(c("abc", ""), ""),
    cbind(start = c(1L, 1L), end = c(0L, 0L))
  )
  expect_identical(re_locate("abc", "$"), cbind(start = 4L, end = 3L))
  expect_identical(substr("abc", 4L, 3L), "")
  # GAP: stringr reports an empty match at 1 as start = 1, end = 1, which
  # substr() reads as one character, and reports no match in "".
  skip_if_not_installed("stringr")
  expect_identical(unname(stringr::str_locate("abc", "")[1, ]), c(1L, 1L))
})

test_that("bytes = TRUE counts bytes", {
  x <- "h\u00e9llo w\u00f6rld"
  expect_identical(re_locate(x, "l+"), cbind(start = 3L, end = 4L))
  expect_identical(
    re_locate(x, "l+", bytes = TRUE),
    cbind(start = 4L, end = 5L)
  )
  b <- re_locate(x, "w\u00f6r", bytes = TRUE)
  expect_identical(rawToChar(charToRaw(x)[b[, "start"]:b[, "end"]]), "w\u00f6r")
  all <- re_locate_all(x, "[\u00e9\u00f6]", bytes = TRUE)
  expect_identical(all$start, c(2L, 9L))
  expect_identical(all$end, c(3L, 10L))
})

test_that("re_locate_all() equals gregexpr(perl = TRUE) on the parity corpus", {
  x <- parity_subjects()
  # Patterns that can match empty differ in one documented way (GAP below).
  nonempty <- setdiff(parity_patterns(), c("a*", "^$", "a?b", "^\\s+|\\s+$"))
  for (p in nonempty) {
    expect_identical(re_locate_all(x, p), base_locate_all(x, p), label = p)
  }
})

test_that("re_locate_all() keeps the empty match after a non-empty one", {
  # GAP: gregexpr() drops the empty match at the end of "baaac"; PCRE2's
  # iteration and stringr's ICU both report it.
  out <- re_locate_all("baaac", "a*")
  expect_identical(out$start, c(1L, 2L, 5L, 6L))
  expect_identical(out$end, c(0L, 4L, 4L, 5L))
  expect_identical(
    as.integer(gregexpr("a*", "baaac", perl = TRUE)[[1]]),
    c(1L, 2L, 5L)
  )
  skip_if_not_installed("stringr")
  st <- stringr::str_locate_all("baaac", "a*")[[1]]
  expect_identical(out$start, unname(st[, "start"]))
  expect_identical(out$end, unname(st[, "end"]))
})

test_that("the js dialect steps past an empty match as JavaScript does", {
  # "aa".match(/a*?/g).length is 3 in JavaScript: three empty matches.
  # PCRE2 retries each position for a non-empty match and finds 5.
  js <- re_compile("a*?", dialect = "js")
  expect_identical(re_count("aa", js), 3L)
  expect_identical(re_count("aa", "a*?"), 5L)
  out <- re_locate_all("aa", js)
  expect_identical(out$start, 1:3)
  expect_identical(out$end, 0:2)
  # "aaa".match(/a*/g) is ["aaa", ""].
  expect_identical(re_count("aaa", re_compile("a*", dialect = "js")), 2L)
  # One character means one code point, not one byte.
  expect_identical(
    re_locate_all("\u00e9\u00e9", re_compile("", dialect = "js"))$start,
    1:3
  )
})

test_that("n limits the matches per element at its edges", {
  x <- c("a1b2c3", "d4", "none")
  expect_identical(nrow(re_locate_all(x, "\\d", n = 0)), 0L)
  one <- re_locate_all(x, "\\d", n = 1)
  expect_identical(one$element, c(1L, 2L))
  expect_identical(one$start, c(2L, 2L))
  expect_identical(re_locate_all(x, "\\d", n = Inf), re_locate_all(x, "\\d"))
  expect_identical(nrow(re_locate_all(x, "\\d", n = 2)), 3L)
  for (bad in list(-1, 1.5, NA, "2", c(1, 2))) {
    expect_error(
      re_locate_all(x, "\\d", n = bad),
      class = "zuregex_error_argument"
    )
  }
})

test_that("overlap finds every overlapping match", {
  out <- re_locate_all("aaaa", "aa", overlap = TRUE)
  expect_identical(out$start, 1:3)
  expect_identical(out$end, 2:4)
  expect_identical(nrow(re_locate_all("aaaa", "aa")), 2L)
  expect_identical(
    re_locate_all("aaaa", "aa", overlap = TRUE, n = 2)$start,
    1:2
  )
  # Overlap steps by characters: matches of two characters at each start.
  wide <- re_locate_all("\u00e9\u00e9\u00e9", "..", overlap = TRUE)
  expect_identical(wide$start, 1:2)
  # Empty matches advance too, and the search ends after the last position.
  expect_identical(re_locate_all("ab", "", overlap = TRUE)$start, 1:3)
})

test_that("NA subjects and patterns give one NA row", {
  out <- re_locate_all(c("ab", NA, "xx"), c("b", "a", NA))
  expect_identical(out$element, 1:3)
  expect_identical(out$match, c(1L, NA, NA))
  expect_identical(out$start, c(2L, NA, NA))
  expect_identical(
    re_locate(c(NA, "a"), "a"),
    cbind(start = c(NA, 1L), end = c(NA, 1L))
  )
})

test_that("a subject with no match has no rows", {
  out <- re_locate_all(c("x", "y"), "z")
  expect_identical(nrow(out), 0L)
  expect_named(out, c("element", "match", "start", "end"))
  expect_s3_class(out, "data.frame")
})

test_that("locate follows the pairing rule", {
  x <- c("ab", "cd")
  expect_identical(
    re_locate(x, c("b", "c")),
    cbind(start = c(2L, 1L), end = c(2L, 1L))
  )
  expect_error(re_locate(x, c("a", "b", "c")), class = "zuregex_error_length")
  expect_error(re_locate_all(x, character()), class = "zuregex_error_length")
})

test_that("locate rejects invalid UTF-8 and bad arguments", {
  bad <- "a\xff"
  Encoding(bad) <- "UTF-8"
  expect_error(re_locate(bad, "a"), class = "zuregex_error_utf")
  expect_error(re_locate_all(c("a", bad), "a"), class = "zuregex_error_utf")
  expect_error(
    re_locate("a", "a", bytes = NA),
    class = "zuregex_error_argument"
  )
  expect_error(
    re_locate_all("a", "a", overlap = 1),
    class = "zuregex_error_argument"
  )
})

test_that("character offsets stay right when a match starts before the last", {
  # \K and overlap move the next offset back, behind the counted prefix.
  x <- "éaébéc"
  out <- re_locate_all(x, "(?<=é)[abc]\\K|é", overlap = TRUE)
  ref <- gregexpr("(?<=é)[abc]\\K|é", x, perl = TRUE)[[1]]
  expect_identical(out$start, as.integer(ref))
  expect_identical(
    re_locate_all(x, "é.", overlap = TRUE)$start,
    c(1L, 3L, 5L)
  )
  expect_identical(
    re_locate_all(x, "(?=(é.))", overlap = TRUE)$start,
    c(1L, 3L, 5L)
  )
})

test_that("re_locate_all() counts characters in linear time", {
  skip_unless_timing()
  # Each match used to recount the subject from its start (#77).
  x <- strrep("éa", 25000)
  bytes <- system.time(re_locate_all(x, "a", bytes = TRUE))[["elapsed"]]
  chars <- system.time(out <- re_locate_all(x, "a"))[["elapsed"]]
  expect_identical(out$start, seq(2L, 50000L, by = 2L))
  expect_lt(chars, 10 * bytes + 0.1)
})

test_that("re_locate() checks bytes", {
  expect_error(re_locate("a", "a", bytes = NA), class = "zuregex_error_argument")
  expect_error(
    re_locate_all("a", "a", bytes = "yes"),
    class = "zuregex_error_argument"
  )
})

test_that("re_escape() output matches the input literally (#171)", {
  ascii <- rawToChar(as.raw(32:126))
  x <- c(
    ascii,
    "a.b*c",
    "\u00e9t\u00e9 (\u2603)",
    "tab\there",
    "line\nbreak\rcr\fff\vvt",
    "unicode \u0085 \u200e \u200f \u2028 \u2029 space",
    "# not a comment",
    ""
  )
  escaped <- re_escape(x)
  # zuregex itself, the whole string (so a `#` that starts a comment under
  # `x` cannot pass on a prefix), in both dialects, and on the bytes of
  # the same text.
  for (i in seq_along(x)) {
    for (flags in c("", "x", "xx")) {
      for (dialect in c("pcre", "js")) {
        label <- paste(dialect, flags, encodeString(x[[i]]))
        p <- re_compile(escaped[[i]], flags = flags, dialect = dialect)
        expect_true(re_detect(x[[i]], p, anchor = "full"), label = label)
        expect_true(
          re_detect(
            charToRaw(x[[i]]),
            escaped[[i]],
            flags = flags,
            anchor = "full"
          ),
          label = paste("bytes", label)
        )
      }
    }
  }
})

test_that("re_escape() refuses input it cannot read as text (#171)", {
  bad <- "\xff."
  Encoding(bad) <- "UTF-8"
  expect_error(re_escape(bad), class = "zuregex_error_argument")
  withr::local_locale(c(LC_CTYPE = "C"))
  skip_if(l10n_info()[["UTF-8"]], "LC_CTYPE could not be set to C")
  skip_if(
    !is.na(iconv("\xff", "", "UTF-8")),
    "byte 0xff is valid in this C locale"
  )
  # R's own conversion would turn the byte into the text <ff>.
  expect_error(re_escape("\xff."), class = "zuregex_error_argument")
})

test_that("re_escape() leaves letters, digits and non-ASCII alone", {
  expect_identical(re_escape("abcXYZ019_\u00e9"), "abcXYZ019_\u00e9")
  expect_identical(re_escape("a+b"), "a\\+b")
  expect_identical(re_escape("a b"), "a\\ b")
})

test_that("re_escape() keeps NA and names, and checks its input", {
  expect_identical(re_escape(c(a = "x.y", b = NA)), c(a = "x\\.y", b = NA))
  expect_identical(re_escape(character()), character())
  expect_error(re_escape(1), class = "zuregex_error_argument")
})

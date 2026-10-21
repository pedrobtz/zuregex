test_that("re_escape() output matches the input literally", {
  ascii <- rawToChar(as.raw(32:126))
  x <- c(
    ascii,
    "a.b*c",
    "\u00e9t\u00e9 (\u2603)",
    "tab\there",
    "line\nbreak\rcr\fff\vvt",
    "unicode \u0085 \u200e \u200f \u2028 \u2029 space",
    ""
  )
  escaped <- re_escape(x)
  for (i in seq_along(x)) {
    for (flags in c("", "x", "xx")) {
      re <- re_compile(escaped[[i]], flags = flags)
      expect_s3_class(re, "re")
      # Base R's PCRE2 as the matcher until re_detect() exists (Stage 3).
      wrapped <- paste0(
        "^(?",
        if (nzchar(flags)) flags else "-x",
        ")",
        escaped[[i]],
        "$"
      )
      expect_true(
        grepl(wrapped, x[[i]], perl = TRUE),
        label = paste(flags, x[[i]])
      )
    }
  }
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

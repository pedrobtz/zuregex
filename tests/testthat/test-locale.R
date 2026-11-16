test_that("a byte invalid in a C locale is not matched as <xx> text (#126)", {
  withr::local_locale(c(LC_CTYPE = "C"))
  skip_if(l10n_info()[["UTF-8"]], "LC_CTYPE could not be set to C")
  # R's own translation writes byte 0xff as the four characters <ff>.
  x <- c("ok", "\xff")
  expect_error(re_detect(x, "f"), class = "zuregex_error_utf")
  expect_error(re_detect(x, "<"), class = "zuregex_error_utf")
  expect_error(re_locate_all(x, "f"), class = "zuregex_error_utf")
  expect_error(re_split("a\xffb", "f"), class = "zuregex_error_utf")
  # Patterns and templates are refused too, with their own class, never
  # read as "<ff>" (#131).
  expect_error(re_detect("<ff>", "\xff"), class = "zuregex_error_compile")
  expect_error(re_replace("a", "a", "\xff"), class = "zuregex_error_template")
})

test_that("a template error counts characters in a C locale (#126)", {
  withr::local_locale(c(LC_CTYPE = "C"))
  skip_if(l10n_info()[["UTF-8"]], "LC_CTYPE could not be set to C")
  err <- expect_error(
    re_replace("b", "b", "\u00e9${x"),
    class = "zuregex_error_template"
  )
  expect_identical(err$position, 5L)
})

test_that("unmarked strings in a Latin-1 locale are still translated", {
  latin1 <- c("en_US.ISO8859-1", "en_US.ISO-8859-1", "en_US.iso88591")
  old <- Sys.getlocale("LC_CTYPE")
  loc <- Find(
    function(l) suppressWarnings(nzchar(Sys.setlocale("LC_CTYPE", l))),
    latin1
  )
  Sys.setlocale("LC_CTYPE", old)
  skip_if(is.null(loc), "no Latin-1 locale")
  withr::local_locale(c(LC_CTYPE = loc))
  x <- "caf\xe9"
  expect_identical(Encoding(x), "unknown")
  expect_true(re_detect(x, "caf\u00e9"))
  expect_identical(re_locate(x, "\u00e9"), cbind(start = 4L, end = 4L))
  expect_identical(re_replace(x, "caf", "th\xe9 "), "th\u00e9 \u00e9")
})

test_that("the C API matches as zuregex's R verbs do", {
  x <- c("a 12-34", "é 5-6", "none")
  expect_identical(
    unname(link_match("\\d+-\\d+", x)),
    unname(zuregex::re_locate(x, "\\d+-\\d+", bytes = TRUE))
  )
})

test_that("the C API substitutes, retrying with the size it reports", {
  expect_identical(
    link_replace("(\\d+)", "a1b22c333", "<$1>"),
    "a<1>b<22>c<333>"
  )
})

test_that("group names and the version come through", {
  expect_identical(link_groups("(?<y>\\d+)-(\\d+)"), c("y", ""))
  expect_identical(
    link_version(),
    paste(
      "PCRE2",
      sub(" .*", "", zuregex::zuregex_info()$pcre2_version),
      zuregex::zuregex_info()$pcre2_date
    )
  )
})

test_that("the consumer links no PCRE2 code of its own", {
  dll <- getLoadedDLLs()[["zuregexlink"]][["path"]]
  nm <- Sys.which("nm")
  skip_if(!nzchar(nm), "nm is not available")
  skip_on_os("windows")
  syms <- suppressWarnings(system2(
    nm,
    shQuote(dll),
    stdout = TRUE,
    stderr = FALSE
  ))
  expect_length(grep("pcre2", syms, value = TRUE), 0L)
})

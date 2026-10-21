test_that("zr_match() gives zero-based, half-open byte offsets", {
  m <- capi_match("(\\d+)-(?<b>\\d+)(x)?", c("a 12-34", "none", "é 1-2"))
  # Rows are groups 0 to 3, columns start and end; -1 for an unset group.
  expect_identical(m[[1]], matrix(c(2L, 2L, 5L, -1L, 7L, 4L, 7L, -1L), 4, 2))
  expect_identical(m[[2]], zr()$NOMATCH)
  # "é" is two bytes, so "1-2" starts at byte 3.
  expect_identical(m[[3]][1, ], c(3L, 6L))
})

test_that("the R verbs and the C API agree on offsets", {
  x <- c("a 12-34", "éé 5-6", "x")
  loc <- re_locate(x, "\\d+-\\d+", bytes = TRUE)
  m <- capi_match("\\d+-\\d+", x)
  for (i in 1:2) {
    # One-based inclusive in R; zero-based half-open in C.
    expect_identical(unname(loc[i, ]), c(m[[i]][1, 1] + 1L, m[[i]][1, 2]))
  }
})

test_that("flags, dialects and match options reach PCRE2", {
  expect_identical(
    capi_match("abc", "ABC", flags = zr()$CASELESS)[[1]][1, ],
    c(0L, 3L)
  )
  expect_identical(capi_match("abc", "ABC")[[1]], zr()$NOMATCH)
  expect_identical(
    capi_match("a.c", c("a.c", "abc"), flags = zr()$LITERAL)[[2]],
    zr()$NOMATCH
  )
  expect_identical(
    capi_match("\\u0041", "A", dialect = 1L)[[1]][1, ],
    c(0L, 1L)
  )
  expect_identical(
    capi_match("b", "ab", options = zr()$ANCHORED)[[1]],
    zr()$NOMATCH
  )
  expect_identical(
    capi_match("a", "ab", options = zr()$ENDANCHORED)[[1]],
    zr()$NOMATCH
  )
  expect_identical(
    capi_match("x*", "ab", options = zr()$NOTEMPTY)[[1]],
    zr()$NOMATCH
  )
  # The interpreter finds what JIT code finds.
  expect_identical(
    capi_match("b+", "abbc", options = 0x10L)[[1]][1, ],
    c(1L, 3L)
  )
  # Bytes: "." is one byte, so two dots match one two-byte character.
  expect_identical(
    capi_match("^..$", "é", flags = zr()$BYTES)[[1]][1, ],
    c(0L, 2L)
  )
  expect_identical(capi_match("^..$", "é")[[1]], zr()$NOMATCH)
})

test_that("invalid UTF-8 and bad arguments are status codes", {
  bad <- "a\xff"
  Encoding(bad) <- "UTF-8"
  expect_identical(capi_match("a", bad)[[1]], zr()$ERROR_UTF)
  expect_identical(
    capi_match("a", "a", options = 0x100L)[[1]],
    zr()$ERROR_ARGUMENT
  )
  expect_error(capi_info("(", "x"), "missing closing parenthesis")
})

test_that("zr_substitute() expands templates, once or globally", {
  expect_identical(capi_substitute("(\\d+)", "a1b22", "<$1>")$out, "a<1>b22")
  res <- capi_substitute("(\\d+)", "a1b22", "<$1>", options = zr()$GLOBAL)
  expect_identical(res$out, "a<1>b<22>")
  expect_identical(res$rc, 2L)
  expect_identical(
    capi_substitute("(\\d+)", "a1", "$1", options = zr()$SUB_LITERAL)$out,
    "a$1"
  )
  expect_identical(capi_substitute("x", "abc", "y")$out, "abc")
  expect_identical(capi_substitute("x", "abc", "y")$rc, 0L)
})

test_that("zr_substitute() reports the size it needs", {
  small <- capi_substitute(
    "(\\d+)",
    "a1b22",
    "<$1>",
    options = zr()$GLOBAL,
    bufsize = 3
  )
  expect_identical(small$rc, zr()$ERROR_NOMEMORY)
  # The result and its terminating NUL.
  expect_identical(small$outlen, 10)
  enough <- capi_substitute(
    "(\\d+)",
    "a1b22",
    "<$1>",
    options = zr()$GLOBAL,
    bufsize = small$outlen
  )
  expect_identical(enough$out, "a<1>b<22>")
  expect_identical(capi_substitute("b", "abc", "${x")$rc, zr()$ERROR_TEMPLATE)
})

test_that("group counts, names and numbers", {
  info <- capi_info("(?<y>\\d+)-(\\d+)(?<z>x)?", "z")
  expect_identical(info$groups, 3L)
  expect_identical(info$names, c("y", NA, "z"))
  expect_identical(info$number, 3L)
  expect_identical(capi_info("(a)", "nope")$number, zr()$ERROR_GROUP)
  expect_match(info$version, "^PCRE2 10\\.48 ")
  expect_identical(capi_info("a", flags = zr()$NO_JIT)$jit, FALSE)
})

test_that("zr_set_limits() bounds a match", {
  rc <- .Call(
    zuregex:::zuregex_capi_limit_c,
    "^(a+)+$",
    paste0(strrep("a", 28), "!"),
    1000
  )
  expect_identical(rc, zr()$ERROR_MATCH_LIMIT)
})

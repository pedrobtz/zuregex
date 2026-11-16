test_that("repetition patterns match long subjects as grepl() does (#166)", {
  # PCRE2's JIT stack is 32 KiB, and a repeated group uses some for each
  # iteration, so these failed from about 1 KB with a jit_stack limit.
  patterns <- c(
    "^(a|b)*$",
    "^(?:.|\\n)*$",
    "^(\\w+,)*\\w+$",
    "\"((?:[^\"\\\\]|\\\\.)*)\"",
    "(?:[^,]*,)+[^,]*"
  )
  for (size in c(1024, 4096, 65536)) {
    units <- c("ab", "a\nb", "ab,", "\"ab\\\"cd\"", "ab,")
    for (k in seq_along(patterns)) {
      x <- strrep(units[[k]], ceiling(size / nchar(units[[k]])))
      p <- patterns[[k]]
      label <- paste(p, "on", size, "characters")
      expect_identical(re_detect(x, p), grepl(p, x, perl = TRUE), label = label)
      m <- regexpr(p, x, perl = TRUE)
      want <- c(m, m + attr(m, "match.length") - 1L)
      if (m < 0) {
        want <- c(NA_integer_, NA_integer_)
      }
      expect_identical(unname(re_locate(x, p)[1, ]), want, label = label)
      # Base R has no whole-match reference, so the pattern is wrapped in
      # a group.
      expect_identical(
        re_replace(x, p, "<$0>"),
        gsub(paste0("(", p, ")"), "<\\1>", x, perl = TRUE),
        label = label
      )
    }
  }
})

test_that("a JIT stack overflow falls back to the interpreter (#166)", {
  x <- strrep("ab", 2e5)
  expect_true(re_detect(x, "^(?:(a)|b)*$"))
  expect_true(re_detect(x, re_compile("^(?:(a)|b)*$", jit = FALSE)))
  # The interpreter's own limits still apply to the retry.
  expect_error(
    re_detect(x, "^(?:(a)|b)*$", limits = re_limits(match = 1000)),
    class = "zuregex_error_limit"
  )
})

test_that("variable-length lookbehinds match as the interpreter does (#167)", {
  # PCRE2's JIT treats the lookbehind point as the end of the subject
  # inside a variable-length lookbehind (upstream PCRE2 #974 and #1004),
  # so the interpreter is the oracle.
  cases <- list(
    list("a(?<=a(?=b)c?)b", "ab"),
    list("(?<=\\R)\\n", "\r\n"),
    list("(?<=\\w{1,2}+)\\w", "ab"),
    list("(?<=a?+)", "aa"),
    list("y(?<!.{1,2}\\b)b", "eyb"),
    list("(?<=\\R)", "a\r\nb")
  )
  for (case in cases) {
    p <- case[[1]]
    x <- case[[2]]
    interpreted <- re_compile(p, jit = FALSE)
    expect_identical(
      re_locate_all(x, p),
      re_locate_all(x, interpreted),
      label = p
    )
    expect_identical(re_detect(x, p), re_detect(x, interpreted), label = p)
  }
  # Known answers, from the interpreter and upstream's PR: base R is no
  # oracle here, as it may use the same JIT.
  expect_true(re_detect("ab", "a(?<=a(?=b)c?)b"))
  expect_false(re_detect("\r\n", "(?<=\\R)\\n"))
  expect_identical(re_extract("eyb", "y(?<!.{1,2}\\b)b"), "yb")
  expect_identical(re_replace("a\r\nb", "(?<=\\R)", "|"), "a\r\n|b")
})

test_that("only variable-length lookbehinds give up the JIT (#167)", {
  skip_if_not(zuregex_info()$jit_usable, "the JIT compiler is not usable here")
  local_cache()
  variable <- c("a(?<=a(?=b)c?)b", "(?<=\\R)\\n", "(*naplb:a?)b", "(?<!x?)y")
  fixed <- c("(?<=abc)d", "(?<!x)y", "(?<=a|bc)d", "\\bfoo\\b", "(?<name>a)")
  expect_identical(re_info(re_compile(variable))$jit, rep(FALSE, 4))
  expect_identical(re_info(re_compile(fixed))$jit, rep(TRUE, 5))
  # A literal pattern has no lookbehind, whatever its text.
  expect_true(re_info(re_compile("(?<=a?)", literal = TRUE))$jit)
})

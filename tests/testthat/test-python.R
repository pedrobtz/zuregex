# Expected values recorded from Python 3.13's re module by
# tools/oracles/python-re.py; regenerate there, not by hand. Python
# writes None for a group that did not take part; R has NA.

test_that("re_split(keep_groups = TRUE) equals Python's re.split()", {
  cases <- list(
    list(pattern = ",\\s*", x = "a, b,c", n = Inf, expected = c("a", "b", "c")),
    list(
      pattern = "(\\d+)",
      x = "a1b22c",
      n = Inf,
      expected = c("a", "1", "b", "22", "c")
    ),
    list(
      pattern = "(-)|(\\+)",
      x = "1-2+3",
      n = Inf,
      expected = c("1", "-", NA, "2", NA, "+", "3")
    ),
    list(
      pattern = "x*",
      x = "axbc",
      n = Inf,
      expected = c("", "a", "", "b", "c", "")
    ),
    list(pattern = "", x = "abc", n = Inf, expected = c("", "a", "b", "c", "")),
    list(
      pattern = "\\b",
      x = "hi there",
      n = Inf,
      expected = c("", "hi", " ", "there", "")
    ),
    list(pattern = "-", x = "a-b-c-d", n = 2, expected = c("a", "b-c-d")),
    list(pattern = "-", x = "a-b-c-d", n = 3, expected = c("a", "b", "c-d")),
    list(
      pattern = "(-)",
      x = "a-b-c-d",
      n = 3,
      expected = c("a", "-", "b", "-", "c-d")
    ),
    list(
      pattern = ",",
      x = ",a,,b,",
      n = Inf,
      expected = c("", "a", "", "b", "")
    ),
    list(
      pattern = "\\s+",
      x = "  lead and trail  ",
      n = Inf,
      expected = c("", "lead", "and", "trail", "")
    ),
    list(
      pattern = "(a)|b",
      x = "xaybz",
      n = Inf,
      expected = c("x", "a", "y", NA, "z")
    ),
    list(pattern = "\\d", x = "no digits", n = Inf, expected = c("no digits")),
    list(pattern = "(?=b)", x = "abab", n = Inf, expected = c("a", "ba", "b")),
    list(
      pattern = "(\u00e9)",
      x = "caf\u00e9 cr\u00e8me",
      n = Inf,
      expected = c("caf", "\u00e9", " cr\u00e8me")
    )
  )
  for (case in cases) {
    got <- re_split(case$x, case$pattern, n = case$n, keep_groups = TRUE)[[1]]
    expect_identical(got, case$expected, label = paste(case$pattern, case$x))
  }
})

test_that("re_replace() equals Python's re.sub()", {
  # Python's \\1 template references are written $1 here.
  cases <- list(
    list(
      pattern = "x*",
      x = "abc",
      replacement = "-",
      n = Inf,
      expected = "-a-b-c-"
    ),
    list(pattern = "a", x = "aaa", replacement = "b", n = 2, expected = "bba"),
    list(
      pattern = "(\\w+)@(\\w+)",
      x = "me@host you@there",
      replacement = "$2 at $1",
      n = Inf,
      expected = "host at me there at you"
    ),
    list(
      pattern = "",
      x = "abc",
      replacement = "-",
      n = Inf,
      expected = "-a-b-c-"
    ),
    list(
      pattern = "a|",
      x = "baac",
      replacement = "-",
      n = Inf,
      expected = "-b---c-"
    ),
    list(
      pattern = "\\d+",
      x = "a1b22c333",
      replacement = "#",
      n = 1,
      expected = "a#b22c333"
    )
  )
  for (case in cases) {
    got <- re_replace(case$x, case$pattern, case$replacement, n = case$n)
    expect_identical(got, case$expected, label = paste(case$pattern, case$x))
  }
})

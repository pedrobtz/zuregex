test_that("every template form of the design's table works", {
  x <- "2026-10-21"
  p <- "(?<y>\\d{4})-(\\d{2})-(\\d{2})(x)?"
  expect_identical(re_replace(x, p, "$3/$2/$1"), "21/10/2026")
  expect_identical(
    re_replace(
      "abcdefghijkl",
      "(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)(k)(l)",
      "${12}${10}"
    ),
    "lj"
  )
  expect_identical(re_replace(x, p, "${y}"), "2026")
  expect_identical(re_replace(x, p, "$0!"), "2026-10-21!")
  expect_identical(re_replace(x, p, "${4:-none}"), "none")
  expect_identical(re_replace(x, p, "${1:-none}"), "2026")
  expect_identical(re_replace(x, p, "${4:+yes:no}"), "no")
  expect_identical(re_replace(x, p, "${2:+yes:no}"), "yes")
  expect_identical(
    re_replace("hello world", "(\\w+) (\\w+)", "\\U$1\\E $2"),
    "HELLO world"
  )
  expect_identical(
    re_replace("HELLO WORLD", "(\\w+) (\\w+)", "\\L$1\\E $2"),
    "hello WORLD"
  )
  expect_identical(re_replace("hello", "(\\w+)", "\\u$1"), "Hello")
  expect_identical(re_replace("HELLO", "(\\w+)", "\\l$1"), "hELLO")
  expect_identical(re_replace("cost", "cost", "$$5"), "$5")
  expect_identical(re_replace("cost", "cost", "\\$5"), "$5")
  # An unset group is "".
  expect_identical(re_replace(x, p, "[$4]"), "[]")
})

test_that("a malformed template is a zuregex_error_template with its position", {
  err <- expect_error(
    re_replace("abc", "b", "x${oops"),
    class = "zuregex_error_template"
  )
  expect_s3_class(err, "zuregex_error")
  expect_identical(err$element, 1)
  expect_identical(err$template, "x${oops")
  expect_type(err$position, "integer")
  expect_error(re_replace("abc", "(b)", "$2"), class = "zuregex_error_template")
  expect_error(
    re_replace("abc", "(b)", "${nope}"),
    class = "zuregex_error_template"
  )
  expect_error(
    re_expand("abc", "b", "${1:+x}"),
    class = "zuregex_error_template"
  )
  expect_snapshot(re_replace(c("a", "b"), "b", "\u00e9${x"), error = TRUE)
  # Reported where a match first uses the template, not before.
  expect_identical(re_replace("abc", "z", "${oops"), "abc")
})

test_that("syntax = \"literal\" inserts the replacement as it is", {
  expect_identical(
    re_replace("a.b", "\\.", "$1\\U", syntax = "literal"),
    "a$1\\Ub"
  )
  expect_identical(re_replace("ab", "", "$", syntax = "literal"), "$a$b$")
})

test_that("re_replace() equals gsub() and sub() for $-free templates", {
  x <- parity_subjects()
  # Patterns that can match empty are compared in the GAP test below.
  nonempty <- setdiff(parity_patterns(), c("a*", "^$", "a?b", "^\\s+|\\s+$"))
  for (p in nonempty) {
    expect_identical(
      re_replace(x, p, "<>"),
      gsub(p, "<>", x, perl = TRUE),
      label = p
    )
    expect_identical(
      re_replace(x, p, "<>", n = 1),
      sub(p, "<>", x, perl = TRUE),
      label = p
    )
  }
})

test_that("empty matches next to a match are replaced, as in Python", {
  # GAP: gsub() skips an empty match right after a non-empty one.
  # PCRE2's iteration, like Python's re.sub() since 3.7, replaces it:
  # re.sub("a*", "<>", "baac") == "<>b<><>c<>".
  expect_identical(re_replace("baac", "a*", "<>"), "<>b<><>c<>")
  expect_identical(gsub("a*", "<>", "baac", perl = TRUE), "<>b<>c<>")
  expect_identical(re_replace("a", "a*", "<>"), "<><>")
})

test_that("group references use $1 where base R uses \\\\1", {
  # GAP: base R and stringr templates write a group as \\1 (design D7);
  # zuregex uses PCRE2's $1, which also reaches groups past nine and by
  # name. The results agree once the template is translated.
  x <- c("2026-10-21", "x")
  expect_identical(
    re_replace(x, "(\\d+)-(\\d+)", "$2-$1"),
    gsub("(\\d+)-(\\d+)", "\\2-\\1", x, perl = TRUE)
  )
  # PCRE2's extended syntax reads \\1 as group 1 too, so base R templates
  # that use only \\1 to \\9 work unchanged.
  expect_identical(re_replace("a1", "(\\d)", "<\\1>"), "a<1>")
  skip_if_not_installed("stringr")
  expect_identical(
    re_replace(x, "(\\d+)-(\\d+)", "$2-$1"),
    stringr::str_replace_all(x, "(\\d+)-(\\d+)", "\\2-\\1")
  )
})

test_that("re_replace() equals stringr::str_replace_all() and str_replace()", {
  skip_if_not_installed("stringr")
  x <- parity_subjects()
  nonempty <- setdiff(parity_patterns(), c("a*", "^$", "a?b", "^\\s+|\\s+$"))
  for (p in nonempty) {
    expect_identical(
      re_replace(x, p, "<>"),
      stringr::str_replace_all(x, p, "<>"),
      label = p
    )
    expect_identical(
      re_replace(x, p, "<>", n = 1),
      stringr::str_replace(x, p, "<>"),
      label = p
    )
  }
})

test_that("n limits replacements at its edges", {
  expect_identical(re_replace("aaa", "a", "b", n = 0), "aaa")
  expect_identical(re_replace("aaa", "a", "b", n = 1), "baa")
  expect_identical(re_replace("aaa", "a", "b", n = 2), "bba")
  expect_identical(re_replace("aaa", "a", "b", n = Inf), "bbb")
})

test_that("a replacement function gets every match once, as a data frame", {
  calls <- 0L
  seen <- NULL
  f <- function(m) {
    calls <<- calls + 1L
    seen <<- m
    toupper(m[["0"]])
  }
  x <- c("a1b22", "none", "c333", NA)
  out <- re_replace(x, "(?<letter>[a-z])(\\d+)", f)
  expect_identical(calls, 1L)
  expect_identical(out, c("A1B22", "none", "C333", NA))
  expect_s3_class(seen, "data.frame")
  expect_named(seen, c("element", "match", "0", "letter", "2"))
  expect_identical(seen$element, c(1L, 1L, 3L))
  expect_identical(seen$match, c(1L, 2L, 1L))
  expect_identical(seen[["0"]], c("a1", "b22", "c333"))
  expect_identical(seen$letter, c("a", "b", "c"))
  expect_identical(seen[["2"]], c("1", "22", "333"))
  # Not called when nothing matches.
  calls <- 0L
  expect_identical(re_replace("xyz", "\\d", f), "xyz")
  expect_identical(calls, 0L)
  # n limits the rows too.
  re_replace(
    "a1b2c3",
    "\\d",
    function(m) {
      expect_identical(nrow(m), 2L)
      rep("#", nrow(m))
    },
    n = 2
  )
})

test_that("a replacement function's result is checked", {
  expect_error(
    re_replace("a1b2", "\\d", function(m) "x"),
    class = "zuregex_error_argument"
  )
  expect_error(
    re_replace("a1", "\\d", function(m) 1),
    class = "zuregex_error_argument"
  )
  expect_identical(
    re_replace(c("a1", "b2"), "\\d", function(m) c(NA, "#")),
    c(NA, "b#")
  )
})

test_that("replacement follows the pairing rule independently of pattern", {
  x <- c("a", "b", "c")
  expect_identical(re_replace(x, ".", c("1", "2", "3")), c("1", "2", "3"))
  expect_identical(re_replace(x, c("a", "b", "c"), "#"), rep("#", 3))
  expect_error(re_replace(x, ".", c("1", "2")), class = "zuregex_error_length")
  expect_identical(re_replace(c("a", "b"), ".", c(NA, "x")), c(NA, "x"))
})

test_that("re_expand() expands the first match, NA where none", {
  x <- c("John Smith", "Ada Lovelace Byron", "single", NA)
  expect_identical(
    re_expand(x, "(\\w+) (\\w+)", "$2, $1"),
    c("Smith, John", "Lovelace, Ada", NA, NA)
  )
  expect_identical(
    re_expand("2026-10", "(?<y>\\d+)-(?<m>\\d+)", "${m}/${y}"),
    "10/2026"
  )
  expect_identical(
    re_expand(c("a1", "b2"), "([a-z])(\\d)", c("$1", "$2")),
    c("a", "2")
  )
})

test_that("strings in, UTF-8 out; bytes in, bytes out", {
  latin1 <- iconv("caf\u00e9", "UTF-8", "latin1")
  out <- re_replace(latin1, "caf", "th\u00e9 ")
  expect_identical(out, "th\u00e9 \u00e9")
  expect_identical(Encoding(out), "UTF-8")
  # Unmatched elements come back as they were.
  expect_identical(re_replace(latin1, "z", "y"), latin1)
  b <- re_replace(charToRaw("caf\u00e9"), "caf", "x")
  expect_identical(Encoding(b), "bytes")
})

test_that("re_split() equals strsplit() for separators that match text", {
  x <- c("a,b,c", "a,,b", "nocomma", "a, b ,c")
  for (p in c(",", ",\\s*", "\\s*,\\s*")) {
    expect_identical(re_split(x, p), strsplit(x, p, perl = TRUE), label = p)
  }
  # GAP: strsplit() drops a trailing empty piece; re.split() and re_split()
  # keep it.
  expect_identical(re_split("a,b,", ","), list(c("a", "b", "")))
  expect_identical(strsplit("a,b,", ",", perl = TRUE), list(c("a", "b")))
})

test_that("re_split() equals stringr::str_split() for non-empty separators", {
  skip_if_not_installed("stringr")
  x <- c("a,b,c", "a,,b", ",lead", "trail,", "none", "")
  expect_identical(re_split(x, ","), stringr::str_split(x, ","))
  expect_identical(re_split(x, ",", n = 2), stringr::str_split(x, ",", n = 2))
})

test_that("re_split() handles n at its edges, and NA", {
  expect_identical(re_split("a-b-c", "-", n = 0), list(character()))
  expect_identical(re_split("a-b-c", "-", n = 1), list("a-b-c"))
  expect_identical(
    re_split(c("a-b", NA), "-"),
    list(c("a", "b"), NA_character_)
  )
  expect_identical(
    re_split(c("a-b", NA), "-", n = 0),
    list(character(), NA_character_)
  )
  expect_identical(re_split("", "-"), list(""))
})

test_that("replace and split check their arguments", {
  expect_error(re_replace("a", "a", 1), class = "zuregex_error_argument")
  expect_error(
    re_replace("a", "a", "b", syntax = "base"),
    class = "zuregex_error_argument"
  )
  expect_error(
    re_replace("a", "a", "b", n = -1),
    class = "zuregex_error_argument"
  )
  expect_error(re_expand("a", "a", 1), class = "zuregex_error_argument")
  expect_error(
    re_split("a", "a", keep_groups = NA),
    class = "zuregex_error_argument"
  )
  expect_error(re_split("a", "a", n = 1.5), class = "zuregex_error_argument")
})

test_that("a template marked as bytes needs bytes subjects", {
  tmpl <- "\xff"
  Encoding(tmpl) <- "bytes"
  expect_error(re_replace("a", "a", tmpl), class = "zuregex_error_argument")
  expect_error(re_expand("a", "a", tmpl), class = "zuregex_error_argument")
  expect_identical(
    charToRaw(re_replace(charToRaw("a"), "a", tmpl)),
    as.raw(0xff)
  )
})

test_that("results of zero length are empty strings, not NA", {
  # An empty result can be built before its thread has written anything.
  expect_identical(re_replace(c("", "a", "aa"), "a*", ""), c("", "", ""))
  expect_identical(re_replace("", "^", ""), "")
  expect_identical(re_expand(c("", "b"), "^", ""), c("", ""))
  expect_identical(re_replace(c("x", ""), "x", ""), c("", ""))
})

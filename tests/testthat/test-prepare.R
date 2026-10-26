# A character vector with one pattern string takes the fast path, a single
# .Call that compiles, matches and builds the result; a vector of patterns
# or an `re` object takes the general path. Both must agree.

test_that("the fast path and the R path give identical results", {
  x <- c(parity_subjects(), NA, "")
  paths <- every_path(x, "(?<w>[a-z]+)(\\d)?")
  fast <- every_path_result(x, paths$fast)
  expect_identical(every_path_result(x, paths$vector), fast)
  expect_identical(every_path_result(x, paths$re), fast)
})

test_that("bytes-marked and latin1 subjects agree on every path", {
  # The bytes scan in zuregex_prepare_c() was never reached (#80).
  b <- "\u00e9"
  Encoding(b) <- "bytes"
  latin1 <- iconv("caf\u00e9 ab1", "UTF-8", "latin1")
  for (x in list(c(b, "ab1", NA), c(latin1, "xy2"))) {
    paths <- every_path(x, "(?<w>[a-z]+)(\\d)?")
    fast <- every_path_result(x, paths$fast)
    expect_identical(every_path_result(x, paths$vector), fast)
    expect_identical(every_path_result(x, paths$re), fast)
  }
  expect_identical(
    re_extract(c(b, "ab"), "(?<n>^..$)", group = "n"),
    c(b, "ab")
  )
})

test_that("the fast path raises classed compile errors with their offset", {
  err <- expect_error(re_detect("abc", "a(b"), class = "zuregex_error_compile")
  expect_identical(err$offset, 4L)
  expect_identical(err$pattern, "a(b")
  expect_error(re_replace("abc", "[", "x"), class = "zuregex_error_compile")
  expect_error(re_extract_all("abc", "a{2,1}"), class = "zuregex_error_compile")
})

test_that("inputs the fast path declines still work", {
  # A pattern in another encoding is translated on the R path.
  latin1 <- iconv("caf\u00e9", "UTF-8", "latin1")
  expect_identical(Encoding(latin1), "latin1")
  expect_true(re_detect("un caf\u00e9", latin1))
  # An NA pattern, raw subjects and bytes-marked subjects.
  expect_identical(re_detect(c("a", "b"), NA_character_), c(NA, NA))
  expect_true(re_detect(as.raw(c(0x61, 0x62)), "ab"))
  b <- "\u00e9"
  Encoding(b) <- "bytes"
  expect_true(re_detect(b, "^..$"))
  # A bytes-marked pattern: matched as bytes.
  pb <- "\u00e9"
  Encoding(pb) <- "bytes"
  expect_true(re_detect(b, pb))
})

test_that("groups that share a name under J share a column on every path", {
  # The fast path gave each group its own column (#76).
  x <- c("x", "y")
  for (p in c("(?<a>x)|(?<a>y)", "(?J)(?<a>x)|(?<a>y)")) {
    flags <- if (startsWith(p, "(?J)")) "" else "J"
    want <- data.frame(a = c("x", "y"))
    expect_identical(re_match(x, p, flags = flags), want)
    expect_identical(
      re_match(x, re_compile(p, flags = flags)),
      want
    )
    all <- re_match_all(x, p, flags = flags)
    expect_named(all, c("element", "match", "a"))
    expect_identical(all$a, c("x", "y"))
  }
})

test_that("the fast path takes the common call and declines the rest", {
  # With the fast path never taken, every comparison above would compare
  # the general path with itself (#87).
  fast <- function(x, p) {
    .Call(
      zuregex:::zuregex_detect_c,
      x,
      NA,
      p,
      NULL,
      zuregex:::no_limits,
      0L,
      FALSE
    )
  }
  expect_identical(fast(c("ab", "cd"), "a"), c(TRUE, FALSE))
  expect_null(fast("ab", NA_character_))
  expect_null(fast("ab", iconv("é", "UTF-8", "latin1")))
  bytes_pattern <- "é"
  Encoding(bytes_pattern) <- "bytes"
  expect_null(fast("ab", bytes_pattern))
  local_cache(0L)
  expect_null(fast("ab", "a"))
})

test_that("the paths raise the same conditions", {
  # Values were compared; conditions were not (#88).
  condition_of <- function(expr) {
    cnd <- tryCatch(
      withCallingHandlers(
        {
          expr
          NULL
        },
        warning = function(w) {
          stop(w)
        }
      ),
      condition = identity
    )
    if (is.null(cnd)) {
      return(NULL)
    }
    list(
      class = class(cnd),
      element = cnd$element,
      offset = cnd$offset,
      limit = cnd$limit,
      count = cnd$count,
      position = cnd$position
    )
  }
  compare <- function(x, pattern, f, re = TRUE) {
    paths <- list(fast = pattern, vector = rep(pattern, length(x)))
    if (re) {
      paths$re <- re_compile(pattern)
    }
    got <- lapply(paths, function(p) condition_of(f(x, p)))
    expect_false(is.null(got$fast))
    for (path in names(got)[-1]) {
      expect_identical(got[[path]], got$fast, label = path)
    }
  }
  case <- pathological()
  x <- c("aa", case$x)
  bad_utf8 <- c("ok", "\xff")
  for (name in names(every_verb())) {
    verb <- every_verb()[[name]]
    compare(x, "a(b", verb, re = FALSE)
    compare(bad_utf8, "a", verb)
    compare(x, case$pattern, function(x, p) {
      verb(x, p, limits = re_limits(match = 1000))
    })
    compare(x, case$pattern, function(x, p) {
      verb(x, p, limits = re_limits(match = 1000, on_limit = "na"))
    })
  }
  compare("abc", "b", function(x, p) re_replace(x, p, "x${oops"))
})

test_that("the paths agree on flags, literal and every argument", {
  x <- c(parity_subjects(), NA, "", "A1 a1", "W1")
  pattern <- "(?<w>[a-z]+)(\\d)?"
  for (flags in c("i", "J", "x")) {
    fast <- every_path_result(x, pattern, flags = flags)
    vector <- every_path_result(x, rep(pattern, length(x)), flags = flags)
    re <- every_path_result(x, re_compile(pattern, flags = flags))
    expect_identical(vector, fast, label = flags)
    expect_identical(re, fast, label = flags)
  }
  literal <- function(x, p, ...) {
    list(
      re_detect(x, p, ...),
      re_locate_all(x, p, ...),
      re_extract_all(x, p, ...),
      re_replace(x, p, "#", ...),
      re_split(x, p, ...)
    )
  }
  fast <- literal(x, "a1", literal = TRUE, flags = "i")
  vector <- literal(x, rep("a1", length(x)), literal = TRUE, flags = "i")
  re <- literal(x, re_compile("a1", literal = TRUE, flags = "i"))
  expect_identical(vector, fast)
  expect_identical(re, fast)

  paths <- every_path(x, "a|")
  run <- function(p) {
    list(
      re_detect(x, p, anchor = "start"),
      re_detect(x, p, anchor = "full", negate = TRUE),
      re_locate(x, p, bytes = TRUE),
      re_locate_all(x, p, overlap = TRUE, bytes = TRUE),
      re_extract_all(x, p, n = 2),
      re_extract_all(x, p, group = 0),
      re_match_all(x, p, n = 1)
    )
  }
  fast <- run(paths$fast)
  expect_identical(run(paths$vector), fast)
  expect_identical(run(paths$re), fast)
})

test_that("every verb takes its fast path for the common call", {
  # Only re_detect()'s fast path was shown to be taken, so the comparisons
  # above could compare the general path with itself (#106).
  general <- character()
  local_mocked_bindings(
    prepare = function(...) {
      general <<- c(general, "called")
      stop("the general path ran")
    }
  )
  x <- c("ab", "cd")
  verbs <- every_verb()
  # A replacement function always takes the general path.
  verbs$re_replace_fun <- NULL
  for (name in names(verbs)) {
    verbs[[name]](x, "a")
    expect_identical(general, character(), label = name)
  }
  # And the mock is what the general path runs.
  try(re_count(x, c("a", "c")), silent = TRUE)
  expect_identical(general, "called")
})

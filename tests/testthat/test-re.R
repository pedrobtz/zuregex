test_that("re objects format, print and subset", {
  re <- re_compile(c("a+", NA, "b"), flags = "i")
  expect_identical(format(re), c("/a+/i", NA, "/b/i"))
  expect_snapshot(print(re))
  sub <- re[c(3, 1)]
  expect_s3_class(sub, "re")
  expect_identical(as.character(sub), c("b", "a+"))
  expect_identical(re_info(sub)$pattern, c("b", "a+"))
  expect_identical(format(re_compile("a.b", literal = TRUE)), "/a.b/ (literal)")
  expect_identical(format(re_compile("a", dialect = "js")), "/a/ (js)")
  expect_snapshot(print(re_compile(character())))
  expect_snapshot(print(re_compile("\\d+\\.")))
})

test_that("re objects survive serialization", {
  re <- re_compile(c("(x)(?<n>y)", NA), flags = "s")
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(re, path)
  back <- readRDS(path)
  expect_identical(re_info(back), re_info(re))
})

test_that("finalizers release patterns the cache no longer holds", {
  re_cache_clear()
  withr::defer(re_cache_clear())
  for (i in 1:200) {
    re_compile(paste0("p", i, "(q)+"))
  }
  re_cache_clear()
  gc()
  gc()
  # Nothing observable to assert in R beyond surviving; valgrind and ASan
  # in CI check that every pattern was freed exactly once.
  expect_identical(zuregex:::cache_stats()$size, 0L)
})

test_that("assignment and c() keep pointers and patterns in step", {
  re <- re_compile(c("a", "b"))
  re[1] <- re_compile("z")
  expect_identical(as.character(re), c("z", "b"))
  expect_identical(re_detect(c("z", "a"), re), c(TRUE, FALSE))
  re[[2]] <- re_compile("y")
  expect_identical(re_info(re)$pattern, c("z", "y"))
  both <- c(re_compile("p"), re_compile(c("q", "r")))
  expect_s3_class(both, "re")
  expect_identical(as.character(both), c("p", "q", "r"))
  expect_identical(re_detect(c("p", "q", "x"), both), c(TRUE, TRUE, FALSE))
  expect_identical(as.character(rep(re_compile("s"), 2)), c("s", "s"))
  expect_identical(as.character(re[[1]]), "z")
  # Different settings cannot share one re vector.
  expect_error(
    re[1] <- re_compile("z", flags = "i"),
    class = "zuregex_error_argument"
  )
  expect_error(
    c(re_compile("a"), re_compile("a", literal = TRUE)),
    class = "zuregex_error_argument"
  )
  expect_error(re[1] <- "z", class = "zuregex_error_argument")
})

test_that("an edited re object is refused with a class", {
  re <- re_compile("a")
  attr(re, "dialect") <- "perl"
  expect_error(re_detect("a", re), class = "zuregex_error_argument")
  expect_error(re_info(re), class = "zuregex_error_argument")
})

test_that("named re vectors subset and assign by name", {
  # [.re kept the full-length names on a shorter vector (#78).
  re <- re_compile(c("a", "b"))
  names(re) <- c("p", "q")
  expect_identical(names(re[2]), "q")
  expect_identical(as.character(re["q"]), "b")
  expect_identical(re_detect(c("a", "b"), re["q"]), c(FALSE, TRUE))
  re["p"] <- re_compile("z")
  expect_identical(as.character(re), c("z", "b"))
  expect_named(re, c("p", "q"))
  expect_named(c(re, re_compile("y")), c("p", "q", ""))
})

test_that("assigning past the end or to a new name is refused", {
  # It used to do nothing, silently (#78).
  re <- re_compile(c("a", "b"))
  expect_error(re[3] <- re_compile("z"), class = "zuregex_error_argument")
  expect_error(re[[3]] <- re_compile("z"), class = "zuregex_error_argument")
  expect_error(re["x"] <- re_compile("z"), class = "zuregex_error_argument")
  expect_identical(as.character(re), c("a", "b"))
})

test_that("re_compile() keeps pattern names", {
  # Names were dropped, so name indexing needed names<- first (#116).
  re <- re_compile(c(year = "\\d{4}", word = "[a-z]+"))
  expect_named(re, c("year", "word"))
  expect_identical(as.character(re["word"]), "[a-z]+")
  expect_null(names(attr(re, "pattern")))
})

test_that("[[ on an re vector takes exactly one existing element", {
  # [[.re was x[i], so it returned NA elements and length-2 vectors (#116).
  re <- re_compile(c(a = "x", b = "y"))
  expect_identical(as.character(re[["b"]]), "y")
  expect_identical(as.character(re[[1]]), "x")
  expect_error(re[[5]], class = "zuregex_error_argument")
  expect_error(re[["zz"]], class = "zuregex_error_argument")
  expect_error(re[[1:2]], class = "zuregex_error_argument")
  # [[<- takes one re object (#117).
  expect_error(
    re[[1]] <- re_compile(c("p", "q")),
    class = "zuregex_error_argument"
  )
})

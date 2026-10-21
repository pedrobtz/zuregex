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

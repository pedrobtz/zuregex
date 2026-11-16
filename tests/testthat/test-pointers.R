test_that("a foreign external pointer in an re object is recompiled (#159)", {
  con <- textConnection("abc")
  withr::defer(close(con))
  r <- re_compile(c("a", "z"))
  q <- unclass(r)
  # Another package's live pointer, where a pattern belongs.
  q[[1]] <- attr(con, "conn_id")
  attributes(q) <- attributes(r)
  expect_identical(re_detect(c("abc", "abc"), q), c(TRUE, FALSE))
  expect_identical(re_info(q)$pattern, c("a", "z"))
  expect_identical(re_locate("xa", q[1]), cbind(start = 2L, end = 2L))
})

test_that("unloading the DLL with live re objects does not crash (#168)", {
  skip_on_cran()
  res <- run_in_child(c(
    "load_zuregex()",
    "gone <- zuregex::re_compile('a+')",
    "keep <- zuregex::re_compile(c('b', 'c'))",
    "invisible(zuregex::re_detect('aaa', 'x+y'))",
    "unload_zuregex()",
    "dll <- getLoadedDLLs()[['zuregex']]",
    "if (!is.null(dll)) dyn.unload(dll[['path']])",
    "rm(gone)",
    "invisible(gc())",
    "invisible(gc())",
    "load_zuregex()",
    "cat('result:', zuregex::re_detect(c('b', 'x'), keep), '\\n')"
  ))
  expect_identical(res$status, 0L)
  expect_true(any(res$output == "result: TRUE FALSE "))
})

test_that("the finalizer registry keeps live patterns as it prunes and grows", {
  local_cache(0L)
  keep <- lapply(1:50, function(i) re_compile(sprintf("k%d$", i)))
  for (round in 1:5) {
    gone <- lapply(1:200, function(i) re_compile(sprintf("g%d", i)))
    rm(gone)
    invisible(gc())
  }
  subjects <- sprintf("k%d", 1:50)
  expect_true(all(mapply(re_detect, subjects, keep)))
})

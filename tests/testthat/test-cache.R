test_that("compiling a pattern again is a cache hit", {
  local_cache()
  before <- zuregex:::cache_stats()
  re_compile("a+b")
  re_compile("a+b")
  re_compile(c("a+b", "a+b"))
  expect_identical(stats_delta(before), c(hits = 3, misses = 1, evictions = 0))
  expect_identical(zuregex:::cache_stats()$size, 1L)
})

test_that("the key includes flags, dialect, literal and jit", {
  local_cache()
  before <- zuregex:::cache_stats()
  re_compile("a")
  re_compile("a", flags = "i")
  re_compile("a", dialect = "js")
  re_compile("a", literal = TRUE)
  re_compile("a", jit = FALSE)
  expect_identical(stats_delta(before), c(hits = 0, misses = 5, evictions = 0))
  # The same flags in another order are the same options, so the same key.
  re_compile("a", flags = "mi")
  before <- zuregex:::cache_stats()
  re_compile("a", flags = "im")
  expect_identical(stats_delta(before), c(hits = 1, misses = 0, evictions = 0))
})

test_that("the least recently used pattern is evicted at capacity", {
  local_cache(3L)
  re_compile(c("a", "b", "c"))
  re_compile("a") # now "b" is the least recently used
  before <- zuregex:::cache_stats()
  re_compile("d")
  expect_identical(stats_delta(before), c(hits = 0, misses = 1, evictions = 1))
  before <- zuregex:::cache_stats()
  re_compile(c("a", "c", "d"))
  expect_identical(stats_delta(before), c(hits = 3, misses = 0, evictions = 0))
  re_compile("b")
  expect_identical(zuregex:::cache_stats()$size, 3L)
})

test_that("patterns over 65,536 characters bypass the cache", {
  local_cache()
  long <- strrep("a", 65537L)
  edge <- strrep("b", 65536L)
  before <- zuregex:::cache_stats()
  re_compile(long)
  re_compile(long)
  re_compile(edge)
  re_compile(edge)
  expect_identical(stats_delta(before), c(hits = 1, misses = 3, evictions = 0))
  expect_identical(zuregex:::cache_stats()$size, 1L)
  # Characters, not bytes: 40,000 two-byte characters are cached.
  wide <- strrep("\u00e9", 40000L)
  re_compile(wide)
  expect_identical(zuregex:::cache_stats()$size, 2L)
})

test_that("re_cache_clear() empties the cache and re objects survive it", {
  local_cache()
  re <- re_compile(c("x(y)", "z"))
  expect_identical(re_cache_clear(), 2L)
  expect_identical(zuregex:::cache_stats()$size, 0L)
  gc()
  expect_identical(re_info(re)$groups, c(1L, 0L))
})

test_that("re_cache_size() gets, sets and shrinks", {
  local_cache(10L)
  expect_identical(re_cache_size(), 10L)
  re_compile(letters[1:8])
  expect_identical(re_cache_size(3), 10L)
  expect_identical(re_cache_size(), 3L)
  expect_identical(zuregex:::cache_stats()$size, 3L)
  # The three most recently used survive.
  before <- zuregex:::cache_stats()
  re_compile(c("f", "g", "h"))
  expect_identical(stats_delta(before)[["hits"]], 3)
  re_cache_size(0)
  expect_identical(zuregex:::cache_stats()$size, 0L)
  re_compile("a")
  expect_identical(zuregex:::cache_stats()$size, 0L)
})

test_that("re_cache_size() rejects capacities outside 0 to 256", {
  local_cache()
  for (bad in list(-1, 257, 1.5, NA, "8", c(1, 2))) {
    expect_error(re_cache_size(bad), class = "zuregex_error_argument")
  }
  expect_silent(re_cache_size(256))
})

test_that("the default capacity is 128", {
  # Every test that changes the capacity restores it (local_cache()), so in
  # any order the suite sees the default here.
  expect_identical(re_cache_size(), 128L)
})

test_that("cached and uncached patterns report the same re_info()", {
  local_cache()
  patterns <- c("(?<a>x)(y)?\\1", "abc+", "[[:alpha:]]+", "\\u0041")
  for (dialect in c("pcre", "js")) {
    for (p in patterns[dialect == "js" | !grepl("\\\\u", patterns)]) {
      re_cache_clear()
      uncached <- re_info(re_compile(p, dialect = dialect))
      cached <- re_info(re_compile(p, dialect = dialect))
      expect_identical(cached, uncached)
      re_cache_size(0)
      bypassed <- re_info(re_compile(p, dialect = dialect))
      expect_identical(bypassed, uncached)
      re_cache_size(128)
    }
  }
})

test_that("a cache hit costs under 5% of a compile", {
  skip_unless_timing()
  local_cache()
  # A pattern whose compilation and JIT compilation are not trivial, and
  # enough repetitions that the timer's resolution does not decide.
  p <- paste0("(?<w", 1:40, ">[a-z]+\\d{2,4}(?:foo|bar|baz))?", collapse = "")
  n <- 2000L
  uncached <- system.time(
    for (i in seq_len(n)) {
      re_cache_clear()
      re_compile(p)
    }
  )[["elapsed"]]
  re_compile(p)
  cached <- system.time(
    for (i in seq_len(n)) {
      re_compile(p)
    }
  )[["elapsed"]]
  expect_lt(cached, 0.05 * uncached)
})

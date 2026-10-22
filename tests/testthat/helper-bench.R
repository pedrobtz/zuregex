# The benchmark corpus (#66): synthetic log lines of about 64 ASCII
# characters, with an id, an e-mail-like token, separators and, on half of
# them, a phone number.
bench_corpus <- function(n = 50000) {
  withr::local_seed(1)
  words <- c(
    "alpha",
    "beta",
    "gamma",
    "delta",
    "error",
    "warn",
    "info",
    "user",
    "login",
    "timeout"
  )
  x <- sprintf(
    "%s %s id=%d user%d@host%d.com %s; %s, call 555-%04d",
    sample(words, n, TRUE),
    sample(words, n, TRUE),
    sample.int(1e6, n, TRUE),
    sample.int(999, n, TRUE),
    sample.int(50, n, TRUE),
    sample(words, n, TRUE),
    sample(words, n, TRUE),
    sample.int(9999, n, TRUE)
  )
  no_phone <- sample.int(n, n / 2)
  x[no_phone] <- sub("call 555-\\d+", "no phone", x[no_phone])
  x
}

# Median seconds per call of f() over `reps` measurements, each after a
# gc(). A measurement repeats f() until it lasts at least 0.1 s, because
# Windows' timer moves in steps of 10 ms and reads a fast call as 0.
median_time <- function(f, reps = 3) {
  once <- system.time(f(), gcFirst = TRUE)[["elapsed"]]
  times <- if (once >= 0.1) {
    1L
  } else {
    as.integer(min(1000, ceiling(0.1 / max(once, 0.001))))
  }
  stats::median(vapply(
    seq_len(reps),
    function(i) {
      system.time(
        for (k in seq_len(times)) {
          f()
        },
        gcFirst = TRUE
      )[["elapsed"]] /
        times
    },
    0
  ))
}

# Expects `ours` to run at least `at_least` times as fast as `theirs`.
# A bound below 1 tolerates noise around "no slower than".
expect_speedup <- function(ours, theirs, at_least, reps = 3) {
  t_ours <- median_time(ours, reps)
  t_theirs <- median_time(theirs, reps)
  ratio <- t_theirs / max(t_ours, 1e-6)
  expect(
    ratio >= at_least,
    sprintf(
      "%.2fx as fast (ours %.1f ms, theirs %.1f ms); expected at least %.2fx.",
      ratio,
      t_ours * 1000,
      t_theirs * 1000,
      at_least
    )
  )
  invisible(ratio)
}

# Timing bounds hold only on uninstrumented builds: coverage, sanitizers,
# valgrind and gctorture slow R or C by different factors, so a ratio means
# nothing there. They run where ZUREGEX_TIMING_TESTS=true, which only the
# R-CMD-check workflow sets; locally, set it to run them. CRAN never sets
# it, so these never run there.
skip_unless_timing <- function() {
  skip_if_not(
    identical(Sys.getenv("ZUREGEX_TIMING_TESTS"), "true"),
    "timing tests run only with ZUREGEX_TIMING_TESTS=true"
  )
}

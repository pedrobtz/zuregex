# Subjects that add up to well over the serial threshold (16 KiB), so
# phase 2 runs on several threads where the build has OpenMP.
big_subjects <- function() {
  withr::local_seed(42)
  base <- c(
    parity_subjects(),
    "x=1; y=22; z=333 foo123bar 2026-10-21 caf\u00e9"
  )
  words <- vapply(
    seq_len(3000),
    function(i) {
      paste(sample(base, 3, replace = TRUE), collapse = " ")
    },
    ""
  )
  words
}

# Runs `f` with the thread cap at n, restoring the cap after.
with_threads <- function(n, f) {
  old <- re_threads(n)
  on.exit(re_threads(old))
  f()
}

# Runs `f` with the serial threshold at `bytes`, so small inputs take the
# parallel path.
with_serial_bytes <- function(bytes, f) {
  old <- zuregex:::serial_bytes(bytes)
  on.exit(zuregex:::serial_bytes(old))
  f()
}

# The fork test forks with parallel::mclapply(), whose children the parent
# kills; CRAN's valgrind would report what each still held. It runs where
# ZUREGEX_FORK_TESTS=true, which the R-CMD-check and macos-openmp workflows
# set, or under NOT_CRAN=true, as devtools::test() and native-checks have.
skip_unless_fork_tests <- function() {
  skip_if_not(
    identical(Sys.getenv("ZUREGEX_FORK_TESTS"), "true") ||
      identical(Sys.getenv("NOT_CRAN"), "true"),
    "fork tests run only with ZUREGEX_FORK_TESTS=true or NOT_CRAN=true"
  )
}

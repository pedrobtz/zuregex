# Subjects that add up to more than the serial threshold (256 KiB), so
# phase 2 runs on several threads where the build has OpenMP.
big_subjects <- function() {
  withr::local_seed(42)
  base <- c(parity_subjects(), "x=1; y=22; z=333 foo123bar 2026-10-21 café")
  words <- vapply(
    seq_len(7000),
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

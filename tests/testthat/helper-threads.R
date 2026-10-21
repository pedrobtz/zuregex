# Subjects that add up to well over the serial threshold (16 KiB), so
# phase 2 runs on several threads where the build has OpenMP.
big_subjects <- function() {
  withr::local_seed(42)
  base <- c(parity_subjects(), "x=1; y=22; z=333 foo123bar 2026-10-21 café")
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

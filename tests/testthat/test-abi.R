# Symbol isolation (design section 4). R has its own libpcre2-8 loaded, a
# different version. If zuregex exported pcre2_* symbols, either library's
# calls could bind to the other's copy. This is a property of
# $(C_VISIBILITY) in src/Makevars still being applied, which R CMD check
# never looks at.

test_that("the shared object exports nothing but R_init_zuregex", {
  skip_if(
    is_instrumented_build(),
    "instrumented build: its runtime exports symbols of its own"
  )
  # _init and _fini come from the toolchain's crti.o; musl's linker exports
  # them where glibc's does not.
  names <- setdiff(exported_symbols(), c("init", "fini", "_init", "_fini"))
  expect_identical(sort(names), "R_init_zuregex")
})

test_that("no PCRE2 or sljit symbol is exported", {
  syms <- exported_symbols()
  expect_length(grep("pcre2|sljit", syms, value = TRUE), 0L)
})

test_that("nothing CRAN's compiled-code check rejects is linked", {
  # Writing R Extensions: compiled code must not write to stdout or stderr,
  # terminate R, or use the system RNG. R CMD check reports these as a NOTE,
  # and CRAN's automated pretest archives an upload on it. Vendored code
  # counts, so a PCRE2 upgrade that brings one back fails here first.
  # Coverage and sanitizer runtimes link stdio and abort themselves, so an
  # instrumented build is skipped; every ordinary CI leg still runs this.
  skip_if(
    is_instrumented_build(),
    "instrumented build: its runtime links stdio and abort"
  )
  forbidden <- c(
    "printf",
    "puts",
    "putchar",
    "fprintf",
    "vprintf",
    "vfprintf",
    "fputs",
    "fputc",
    "fwrite",
    "perror",
    "stdout",
    "stderr",
    "__stdoutp",
    "__stderrp",
    "__acrt_iob_func",
    "abort",
    "exit",
    "_exit",
    "_Exit",
    "quick_exit",
    "rand",
    "srand",
    "random",
    "srandom",
    "drand48",
    "srand48",
    "lrand48"
  )
  undefined <- sub("@.*$", "", undefined_symbols())
  expect_identical(intersect(undefined, forbidden), character())
})

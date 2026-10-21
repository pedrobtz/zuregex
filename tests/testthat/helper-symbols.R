# Symbol-audit helpers, after zucrypt's. In a helper file because testthat
# sources helper-*.R in every worker, and file-scope objects in a test file
# are not shared.

zuregex_dll_path <- function() {
  dll <- getLoadedDLLs()[["zuregex"]]
  skip_if(is.null(dll), "the zuregex DLL is not loaded")
  path <- dll[["path"]]
  skip_if(!file.exists(path), "the zuregex shared object is not on disk")
  path
}

run_nm <- function(args) {
  nm <- Sys.which("nm")
  skip_if(!nzchar(nm), "nm is not available")
  out <- suppressWarnings(
    system2(
      nm,
      c(args, shQuote(zuregex_dll_path())),
      stdout = TRUE,
      stderr = FALSE
    )
  )
  skip_if(!is.character(out) || length(out) == 0L, "nm produced no output")
  # The last field is the name; Mach-O prefixes C names with an underscore.
  sub("^_", "", sub("^.*[[:space:]]", "", out))
}

# What another library in the process could bind to. ELF: `nm -D` reads the
# dynamic table, where plain `nm` would list hidden symbols too. Mach-O:
# `nm -gU` is global and defined. Windows is skipped: a DLL exports only what
# its export table names, and each module has its own namespace, so two
# copies of PCRE2 cannot bind to each other there at all.
exported_symbols <- function() {
  skip_on_os("windows")
  if (Sys.info()[["sysname"]] == "Darwin") {
    run_nm("-gU")
  } else {
    run_nm(c("-D", "--defined-only"))
  }
}

# What the shared object needs from elsewhere: libc, R, and nothing CRAN's
# compiled-code check objects to.
undefined_symbols <- function() {
  skip_on_os("windows")
  if (Sys.info()[["sysname"]] == "Darwin") {
    run_nm("-u")
  } else {
    run_nm(c("-D", "-u"))
  }
}

# Does this build carry a coverage or sanitizer runtime? Those export and
# reference symbols of their own, which makes the exact export assertion
# meaningless there and only there.
is_instrumented_build <- function() {
  if (identical(Sys.getenv("R_COVR"), "true")) {
    return(TRUE)
  }
  nm <- Sys.which("nm")
  dll <- getLoadedDLLs()[["zuregex"]]
  if (!nzchar(nm) || is.null(dll) || !file.exists(dll[["path"]])) {
    return(FALSE)
  }
  args <- if (Sys.info()[["sysname"]] == "Darwin") "-g" else "-D"
  syms <- suppressWarnings(
    system2(nm, c(args, shQuote(dll[["path"]])), stdout = TRUE, stderr = FALSE)
  )
  is.character(syms) &&
    any(grepl("gcov|__llvm_prof|__asan_|__ubsan_|__tsan_|__msan_", syms))
}

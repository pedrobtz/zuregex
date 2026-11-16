# Runs R code in a child R process with the zuregex under test loaded, and
# returns its output and exit status. For tests whose failure is a crash,
# which would otherwise end the whole suite. Under devtools::test() the
# child loads the source tree with pkgload; under R CMD check it loads the
# installed package from the same library paths.
run_in_child <- function(code) {
  # pkgload is loaded only under devtools::test(), which is the one case
  # that needs it, so it is reached without being a dependency.
  dev <- isNamespaceLoaded("pkgload") &&
    getExportedValue("pkgload", "is_dev_package")("zuregex")
  load <- if (dev) {
    sprintf(
      "pkgload::load_all(%s, quiet = TRUE, export_all = FALSE)",
      deparse1(getExportedValue("pkgload", "pkg_path")())
    )
  } else {
    "loadNamespace('zuregex')"
  }
  unload <- if (dev) {
    "pkgload::unload('zuregex')"
  } else {
    "unloadNamespace('zuregex')"
  }
  script <- withr::local_tempfile(fileext = ".R")
  writeLines(
    c(
      sprintf(".libPaths(%s)", deparse1(.libPaths())),
      sprintf("load_zuregex <- function() %s", load),
      sprintf("unload_zuregex <- function() %s", unload),
      code
    ),
    script
  )
  rscript <- file.path(R.home("bin"), "Rscript")
  out <- suppressWarnings(
    system2(
      rscript,
      c("--vanilla", shQuote(script)),
      stdout = TRUE,
      stderr = TRUE
    )
  )
  list(output = out, status = attr(out, "status") %||% 0L)
}

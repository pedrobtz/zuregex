# PCRE2's own test results, run through the C API (design section 9): the
# Perl-compatible tests without UTF (testoutput1) and with it (testoutput4)
# of the vendored release. tools/pcre2-testdata/convert.py made the corpus;
# tools/pcre2-testdata/skipped.tsv lists every case it left out and why.

test_that("the corpus and the skip list cover every case of both files", {
  cases <- pcre2_cases()
  skipped <- utils::read.delim(
    test_path("..", "..", "tools", "pcre2-testdata", "skipped.tsv"),
    colClasses = "character"
  ) |>
    tryCatch(error = function(e) NULL)
  skip_if(is.null(skipped), "tools/ is not installed")
  expect_gt(nrow(cases), 3500)
  expect_true(all(nzchar(skipped$reason)))
  ids <- c(paste(cases$source, cases$case), paste(skipped$source, skipped$case))
  expect_false(anyDuplicated(ids) > 0)
})

test_that("PCRE2's testdata results hold through the C API", {
  cases <- pcre2_cases()
  # The same pattern can appear with and without UTF in one file.
  key <- paste(cases$source, cases$pattern, cases$flags, cases$utf)
  failures <- character()
  for (k in unique(key)) {
    rows <- cases[key == k, , drop = FALSE]
    utf <- rows$utf[[1]] == "1"
    pattern <- bytes_string(unhex(rows$pattern[[1]]))
    flags <- zr_flags(rows$flags[[1]], utf)
    if (all(rows$expected == "error")) {
      res <- tryCatch(
        capi_match(pattern, character(), flags = flags),
        error = function(e) e
      )
      if (!inherits(res, "error")) {
        failures <- c(
          failures,
          paste("should not compile:", rows$source[[1]], rows$case[[1]])
        )
      }
      next
    }
    rows <- rows[rows$expected != "error", , drop = FALSE]
    subjects <- vapply(
      rows$subject,
      function(h) bytes_string(unhex(h)),
      "",
      USE.NAMES = FALSE
    )
    got <- capi_match(pattern, subjects, flags = flags)
    for (i in seq_len(nrow(rows))) {
      id <- paste(rows$source[[i]], rows$case[[i]])
      if (rows$expected[[i]] == "nomatch") {
        if (!identical(got[[i]], -1L)) {
          failures <- c(failures, paste("expected no match:", id))
        }
        next
      }
      m <- got[[i]]
      if (!is.matrix(m)) {
        failures <- c(failures, paste("expected a match:", id, "status", m))
        next
      }
      # Keep empty fields: an empty group is "" in hex. strsplit() alone
      # drops a trailing empty field.
      expected <- utils::head(
        strsplit(paste0(rows$expected[[i]], ",."), ",", fixed = TRUE)[[1]],
        -1
      )
      subject <- unhex(rows$subject[[i]])
      for (g in seq_len(nrow(m))) {
        start <- m[g, 1]
        want <- if (g <= length(expected) && expected[[g]] != "-") {
          rawToChar(unhex(expected[[g]]))
        }
        have <- if (start >= 0) {
          pcre2test_print(subject[seq_len(m[g, 2] - start) + start], utf)
        }
        if (!identical(have, want)) {
          failures <- c(failures, sprintf("%s group %d", id, g - 1L))
          break
        }
      }
    }
  }
  expect_identical(failures, character())
})

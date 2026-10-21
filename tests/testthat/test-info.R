test_that("zuregex_info() reports the bundled PCRE2", {
  info <- zuregex_info()
  # Must match version_string in tools/vendor/manifest.tsv, which
  # tools/vendor/verify checks; tools/ is not installed, so the literal is
  # duplicated here.
  expect_identical(info$pcre2_version, "10.48")
  expect_match(info$pcre2_date, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
  expect_true(info$unicode)
  expect_match(info$unicode_version, "^[0-9]+\\.[0-9]+\\.[0-9]+$")
  expect_true(info$jit)
})

test_that("zuregex_info() returns its documented fields with their types", {
  info <- zuregex_info()
  expect_named(
    info,
    c(
      "pcre2_version",
      "pcre2_date",
      "unicode",
      "unicode_version",
      "jit",
      "jit_usable",
      "jit_target"
    )
  )
  for (field in c("unicode", "jit", "jit_usable")) {
    expect_true(is_flag(info[[field]]), label = field)
  }
  expect_type(info$jit_target, "character")
  expect_length(info$jit_target, 1L)
})

test_that("the JIT compiler works on the CPUs CRAN checks on", {
  # sljit supports x86-64 and arm64, so a failure there means the system
  # refused executable memory or the build lost SUPPORT_JIT; either one
  # would leave every match on the slower interpreter without a word.
  arch <- R.version$arch
  skip_if_not(arch %in% c("x86_64", "aarch64", "arm64"), arch)
  info <- zuregex_info()
  expect_true(info$jit_usable)
  expect_match(info$jit_target, "x86|ARM", ignore.case = TRUE)
})

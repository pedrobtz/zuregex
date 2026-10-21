# Helpers for test-pcre2-testdata.R: reading the corpus, decoding its hex
# fields, and printing matches as pcre2test does.

pcre2_cases <- function() {
  path <- test_path("fixtures", "pcre2-testdata.tsv.gz")
  utils::read.delim(
    path,
    colClasses = "character",
    quote = "",
    na.strings = character()
  )
}

unhex <- function(h) {
  if (identical(h, "-")) {
    return(NULL)
  }
  if (!nzchar(h)) {
    return(raw())
  }
  as.raw(strtoi(substring(h, seq(1, nchar(h), 2), seq(2, nchar(h), 2)), 16L))
}

bytes_string <- function(r) {
  s <- rawToChar(r)
  Encoding(s) <- "bytes"
  s
}

# Matched bytes as pcre2test prints them: printable ASCII as is, other
# bytes as \xhh without UTF, other characters as \x{h...} with it.
pcre2test_print <- function(bytes, utf) {
  if (utf) {
    cps <- utf8ToInt(rawToChar(bytes))
    out <- ifelse(
      cps >= 0x20 & cps <= 0x7e,
      vapply(cps, intToUtf8, ""),
      sprintf("\\x{%02x}", cps)
    )
  } else {
    v <- as.integer(bytes)
    out <- ifelse(
      v >= 0x20 & v <= 0x7e,
      vapply(bytes, rawToChar, ""),
      sprintf("\\x%02x", v)
    )
  }
  paste(out, collapse = "")
}

zr_flags <- function(letters, utf) {
  bits <- c(i = 0x1, m = 0x2, s = 0x4, x = 0x8, n = 0x20, J = 0x80, u = 0x100)
  if (identical(letters, "-")) {
    letters <- ""
  }
  flags <- 0
  if (grepl("xx", letters, fixed = TRUE)) {
    flags <- flags + 0x10
    letters <- sub("xx", "", letters, fixed = TRUE)
  }
  for (ch in strsplit(letters, "")[[1]]) {
    flags <- flags + bits[[ch]]
  }
  if (!utf) {
    flags <- flags + 0x20000 # ZR_BYTES
  }
  flags
}

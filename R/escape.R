#' Quote regular expression metacharacters
#'
#' Escapes every character that has a meaning in a PCRE2 pattern, so that
#' the result matches `x` literally, as Go's `QuoteMeta()` does. The result
#' is also literal under the `x` flag, which gives whitespace and `#` a
#' meaning. To match a whole pattern literally, `literal = TRUE` in
#' [re_compile()] is simpler.
#'
#' @param x A character vector. `NA` stays `NA`.
#' @return A character vector as long as `x`, in UTF-8.
#' @export
#' @examples
#' re_escape("1+1=2 (really?)")
re_escape <- function(x) {
  if (!is.character(x)) {
    zuregex_abort(
      "argument",
      sprintf("`x` must be a character vector, not %s.", describe(x)),
      call = sys.call()
    )
  }
  # PCRE2 allows a backslash before any ASCII punctuation, and reads it as
  # that character, so escaping a few more than strictly needed is safe.
  out <- gsub("([][\\\\^$.|?*+(){}#/ -])", "\\\\\\1", enc2utf8(x), perl = TRUE)
  # Control whitespace is written as an escape sequence, which the `x` flag
  # does not skip. Two vectors, not names: R converts names to the native
  # encoding, so in a C locale "\u0085" would become the text "<U+0085>".
  from <- c(
    "\n",
    "\t",
    "\r",
    "\f",
    "\v",
    # The Unicode white space PCRE2 also skips under `x` in UTF mode.
    "\u0085",
    "\u200e",
    "\u200f",
    "\u2028",
    "\u2029"
  )
  to <- c(
    "\\n",
    "\\t",
    "\\r",
    "\\f",
    "\\x0b",
    "\\x{85}",
    "\\x{200e}",
    "\\x{200f}",
    "\\x{2028}",
    "\\x{2029}"
  )
  for (k in seq_along(from)) {
    out <- gsub(from[[k]], to[[k]], out, fixed = TRUE)
  }
  out[is.na(x)] <- NA_character_
  names(out) <- names(x)
  out
}

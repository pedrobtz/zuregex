#' Detect and count matches
#'
#' `re_detect()` reports whether each element of `x` matches its pattern.
#' `re_count()` counts the non-overlapping matches in each element.
#'
#' @section Patterns:
#' `pattern` is a character vector of regular expressions, compiled through
#' the cache with the default options, or an `re` vector from
#' [re_compile()] for flags, dialects and literal patterns. It has length 1,
#' used for every element of `x`, or exactly the length of `x`, pairing
#' `pattern[i]` with `x[i]`. Any other length is an error: nothing is
#' recycled. An `NA` pattern gives `NA` for its element.
#'
#' @section Strings and bytes:
#' Character input is matched as UTF-8; strings in other declared encodings
#' are translated first. Invalid UTF-8 is an error of class
#' `zuregex_error_utf`. A raw vector is one subject matched as bytes, as is
#' each element of a list of raw vectors, and so is a character vector with
#' any element marked as `"bytes"`. Patterns are then compiled without UTF-8
#' support, so `.` matches one byte.
#'
#' @param x A character vector, a raw vector, or a list of raw vectors.
#'   `NA` (or `NULL` in a list) gives `NA`.
#' @param pattern A character vector or an `re` vector; see Patterns.
#' @param anchor Where a match must be: `"none"` anywhere, `"start"` at the
#'   start of the subject (Python's `re.match()`), `"full"` the whole
#'   subject (Python's `re.fullmatch()`). Anchoring is done by PCRE2, so it
#'   holds for every branch of a top-level alternation.
#' @param negate If `TRUE`, return `TRUE` for elements that do not match.
#' @param limits A [re_limits()] object, or `NULL` for
#'   `getOption("zuregex.limits")` and then PCRE2's defaults.
#' @return `re_detect()`: a logical vector, one per subject. `re_count()`:
#'   an integer vector, one per subject.
#' @export
#' @examples
#' x <- c("apple", "banana", "cherry", NA)
#' re_detect(x, "an")
#' re_detect(x, "a|b", anchor = "start")
#' re_count(x, "[aeiou]")
#'
#' # One pattern per element
#' re_detect(c("abc", "abc"), c("^a", "^b"))
re_detect <- function(
  x,
  pattern,
  anchor = c("none", "start", "full"),
  negate = FALSE,
  limits = NULL
) {
  call <- sys.call()
  if (missing(anchor)) {
    anchor <- 0L
  } else {
    check_choice(anchor, c("none", "start", "full"), "anchor", call)
    anchor <- match(anchor, c("none", "start", "full")) - 1L
  }
  if (!is.logical(negate) || length(negate) != 1L || is.na(negate)) {
    check_flag(negate, "negate", call)
  }
  lim <- if (is.null(limits) && is.null(getOption("zuregex.limits"))) {
    no_limits
  } else {
    call_limits(limits, call)
  }
  out <- NULL
  if (is.character(x) && is.character(pattern) && length(pattern) == 1L) {
    out <- withCallingHandlers(
      .Call(zuregex_detect_c, x, NA, pattern, NULL, lim, anchor, negate),
      error = function(e) native_error(e, call)
    )
    if (is.object(out)) {
      out <- fast_result(out, call, pattern)
    }
  }
  if (is.null(out)) {
    out <- run_verb(
      {
        s <- p <- prepare(x, pattern, call)
        .Call(
          zuregex_detect_c,
          s$x,
          s$bytes,
          p$table,
          p$index,
          lim,
          anchor,
          negate
        )
      },
      call
    )
  }
  out
}

#' @rdname re_detect
#' @export
re_count <- function(x, pattern, limits = NULL) {
  call <- sys.call()
  lim <- if (is.null(limits) && is.null(getOption("zuregex.limits"))) {
    no_limits
  } else {
    call_limits(limits, call)
  }
  out <- NULL
  if (is.character(x) && is.character(pattern) && length(pattern) == 1L) {
    out <- withCallingHandlers(
      .Call(zuregex_count_c, x, NA, pattern, NULL, lim),
      error = function(e) native_error(e, call)
    )
    if (is.object(out)) {
      out <- fast_result(out, call, pattern)
    }
  }
  if (is.null(out)) {
    out <- run_verb(
      {
        s <- p <- prepare(x, pattern, call)
        .Call(
          zuregex_count_c,
          s$x,
          s$bytes,
          p$table,
          p$index,
          lim
        )
      },
      call
    )
  }
  out
}

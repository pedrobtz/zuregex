#' Locate matches
#'
#' `re_locate()` finds the first match in each element of `x`;
#' `re_locate_all()` finds every match.
#'
#' Offsets are one-based and inclusive, as [regexpr()] and
#' [stringr::str_locate()] report them, so `substr(x, start, end)` extracts
#' a match, and for raw input so does `x[start:end]`. An empty match at
#' position `k` has `start = k` and `end = k - 1`. Offsets count characters,
#' or bytes with `bytes = TRUE`; for raw input the two are the same.
#'
#' After an empty match, the next search follows the pattern's dialect: for
#' `"pcre"` PCRE2's rule, which first tries for a non-empty match at the
#' same position, and for `"js"` JavaScript's, which moves on one
#' character.
#'
#' @inheritParams re_detect
#' @inheritSection re_detect Patterns
#' @inheritSection re_detect Strings and bytes
#' @param bytes If `TRUE`, offsets count bytes instead of characters.
#' @param n The most matches to return per element, `Inf` for all.
#' @param overlap If `TRUE`, each search starts one character after the
#'   start of the previous match, so matches may overlap.
#' @return `re_locate()`: an integer matrix with columns `start` and `end`
#'   and one row per subject, `NA` where there is no match.
#'
#'   `re_locate_all()`: a data frame with one row per match and columns
#'   `element` (the subject's index), `match` (the match's number within
#'   the element), `start` and `end`. A subject with no match has no rows;
#'   an `NA` subject or pattern has one row with `match`, `start` and `end`
#'   `NA`.
#' @export
#' @examples
#' x <- c("apple pie", "banana", NA)
#' loc <- re_locate(x, "an+")
#' loc
#' substr(x, loc[, "start"], loc[, "end"])
#'
#' re_locate_all(x, "[aeiou]")
#' re_locate_all("aaaa", "aa", overlap = TRUE)
re_locate <- function(
  x,
  pattern,
  bytes = FALSE,
  flags = "",
  literal = FALSE,
  limits = NULL
) {
  call <- sys.call()
  opts <- if (missing(flags) && missing(literal)) {
    NULL
  } else {
    pattern_options(flags, literal, call)
  }
  if (!is.logical(bytes) || length(bytes) != 1L || is.na(bytes)) {
    check_flag(bytes, "bytes", call)
  }
  lim <- if (is.null(limits) && is.null(getOption("zuregex.limits"))) {
    no_limits
  } else {
    call_limits(limits, call)
  }
  out <- NULL
  if (is.character(x) && is.character(pattern) && length(pattern) == 1L) {
    out <- withCallingHandlers(
      .Call(zuregex_locate_c, x, NA, pattern, opts, lim, !bytes),
      error = function(e) native_error(e, call)
    )
    if (is.object(out)) {
      out <- fast_result(out, call, pattern, opts = opts)
    }
  }
  if (is.null(out)) {
    out <- run_verb(
      {
        s <- p <- prepare(x, pattern, call, opts)
        .Call(
          zuregex_locate_c,
          s$x,
          s$bytes,
          p$table,
          p$index,
          lim,
          !bytes
        )
      },
      call
    )
  }
  out
}

#' @rdname re_locate
#' @export
re_locate_all <- function(
  x,
  pattern,
  n = Inf,
  overlap = FALSE,
  bytes = FALSE,
  flags = "",
  literal = FALSE,
  limits = NULL
) {
  call <- sys.call()
  opts <- if (missing(flags) && missing(literal)) {
    NULL
  } else {
    pattern_options(flags, literal, call)
  }
  if (!missing(n)) {
    check_n(n, call)
  }
  if (!is.logical(overlap) || length(overlap) != 1L || is.na(overlap)) {
    check_flag(overlap, "overlap", call)
  }
  if (!is.logical(bytes) || length(bytes) != 1L || is.na(bytes)) {
    check_flag(bytes, "bytes", call)
  }
  lim <- if (is.null(limits) && is.null(getOption("zuregex.limits"))) {
    no_limits
  } else {
    call_limits(limits, call)
  }
  cols <- NULL
  if (is.character(x) && is.character(pattern) && length(pattern) == 1L) {
    cols <- withCallingHandlers(
      .Call(
        zuregex_locate_all_c,
        x,
        NA,
        pattern,
        opts,
        lim,
        as.double(n),
        overlap,
        !bytes
      ),
      error = function(e) native_error(e, call)
    )
    if (is.object(cols)) {
      cols <- fast_result(cols, call, pattern, opts = opts)
    }
  }
  if (is.null(cols)) {
    cols <- run_verb(
      {
        s <- p <- prepare(x, pattern, call, opts)
        .Call(
          zuregex_locate_all_c,
          s$x,
          s$bytes,
          p$table,
          p$index,
          lim,
          as.double(n),
          overlap,
          !bytes
        )
      },
      call
    )
  }
  as_data_frame(cols)
}

# A data frame from a named list of equal-length columns, without the
# checks data.frame() spends time on.
as_data_frame <- function(cols, n = NULL) {
  if (is.null(n)) {
    n <- if (length(cols)) length(cols[[1L]]) else 0L
  }
  attr(cols, "row.names") <- .set_row_names(n)
  class(cols) <- "data.frame"
  cols
}

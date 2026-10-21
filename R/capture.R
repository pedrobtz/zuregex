#' Extract matches and capture groups
#'
#' `re_extract()` returns the first match in each element of `x`, or one of
#' its groups; `re_extract_all()` returns every match. `re_match()` returns
#' every group of the first match as a data frame with one row per element;
#' `re_match_all()` returns one row per match. The strings are built in C,
#' without the per-match R overhead of [regmatches()] or
#' [utils::strcapture()].
#'
#' @section Groups and columns:
#' Groups are numbered from 1; group 0 is the whole match. In `re_match()`
#' a named group's column takes its name and an unnamed group's column its
#' number, so `(?<year>\\d+)-(\\d+)` gives the columns `year` and `2`. A
#' group that did not take part in the match is `NA`.
#'
#' With one pattern per element, the columns are the union of the
#' patterns' groups in order of first appearance: groups with the same
#' name share a column, unnamed groups share a column by position, and an
#' element whose pattern lacks a group has `NA` there.
#'
#' @inheritParams re_locate
#' @inheritSection re_detect Patterns
#' @inheritSection re_detect Strings and bytes
#' @param group The group to extract: a number, 0 for the whole match, or a
#'   group name.
#' @param proto `NULL` for character columns, or a data frame or list with
#'   one element per group, as for [utils::strcapture()]: each column is
#'   converted with `as.<class>()` for the class of the matching element,
#'   and takes its name. S4 classes are not supported.
#' @return `re_extract()`: a character vector, `NA` where there is no match.
#'   `re_extract_all()`: a list of character vectors, `NA` for an `NA`
#'   subject or pattern.
#'
#'   `re_match()`: a data frame with one row per subject and one column per
#'   group, all `NA` where there is no match. `re_match_all()`: a data frame
#'   with `element` and `match` columns, then one column per group, one row
#'   per match; a subject with no match has no rows, and an `NA` subject or
#'   pattern one row of `NA`.
#'
#'   Strings from character input are in UTF-8; from bytes they are marked
#'   as `"bytes"`.
#' @export
#' @examples
#' x <- c("2026-10-21", "1999-01-02 and 2000-03-04", "none", NA)
#' re_extract(x, "\\d{4}")
#' re_extract(x, "(?<year>\\d{4})-(\\d{2})", group = "year")
#' re_extract_all(x, "\\d{4}")
#'
#' re_match(x, "(?<year>\\d{4})-(?<month>\\d{2})")
#' re_match(x, "(\\d{4})-(\\d{2})", proto = data.frame(year = 0L, month = 0L))
#' re_match_all(x, "(?<year>\\d{4})")
re_extract <- function(x, pattern, group = 0, limits = NULL) {
  call <- sys.call()
  extract(x, pattern, group, all = FALSE, n = 1, limits, call = call)
}

#' @rdname re_extract
#' @export
re_extract_all <- function(x, pattern, group = 0, n = Inf, limits = NULL) {
  call <- sys.call()
  check_n(n, call)
  extract(x, pattern, group, all = TRUE, n = n, limits, call = call)
}

#' @rdname re_extract
#' @export
re_match <- function(x, pattern, proto = NULL, limits = NULL) {
  call <- sys.call()
  out <- match_groups(x, pattern, all = FALSE, n = 1, limits, call = call)
  if (!is.null(proto)) {
    out <- conform_to_proto(out, proto, call)
  }
  out
}

#' @rdname re_extract
#' @export
re_match_all <- function(x, pattern, n = Inf, limits = NULL) {
  call <- sys.call()
  check_n(n, call)
  match_groups(x, pattern, all = TRUE, n = n, limits, call = call)
}

check_n <- function(n, call) {
  if (
    !is.numeric(n) ||
      length(n) != 1L ||
      is.na(n) ||
      n < 0 ||
      (is.finite(n) && n != trunc(n))
  ) {
    zuregex_abort(
      "argument",
      sprintf(
        "`n` must be a whole number of 0 or more, or `Inf`, not %s.",
        describe(n)
      ),
      call = call
    )
  }
}

# Group names of each pattern in a call's table: "" for unnamed groups.
table_groups <- function(table) {
  .Call(zuregex_re_info_c, table)$group_names
}

extract <- function(x, pattern, group, all, n, limits, call) {
  s <- subjects(x, call)
  p <- patterns(pattern, s$n, s$bytes, call)
  groups <- table_groups(p$table)
  idx <- group_index(group, groups, call)
  run_verb(
    .Call(
      zuregex_extract_c,
      s$x,
      s$bytes,
      p$table,
      p$index,
      call_limits(limits, call),
      idx,
      all,
      as.double(n)
    ),
    call
  )
}

# The group to extract, per pattern in the table: its number, or -1 where
# that pattern does not have it. A group no pattern has is an error.
group_index <- function(group, groups, call) {
  if (
    is.character(group) && length(group) == 1L && !is.na(group) && nzchar(group)
  ) {
    idx <- vapply(groups, function(g) match(group, g, nomatch = 0L), 1L)
    if (length(groups) > 0L && all(idx == 0L)) {
      zuregex_abort(
        "group",
        sprintf("No pattern has a group named \"%s\".", group),
        group = group,
        call = call
      )
    }
    idx[idx == 0L] <- -1L
    return(as.integer(idx))
  }
  if (
    is.numeric(group) &&
      length(group) == 1L &&
      !is.na(group) &&
      group >= 0 &&
      group == trunc(group)
  ) {
    counts <- lengths(groups)
    if (length(groups) > 0L && group > max(counts)) {
      zuregex_abort(
        "group",
        sprintf(
          "`group` is %d, but the pattern%s at most %d group%s.",
          as.integer(group),
          if (length(groups) > 1L) "s have" else " has",
          max(counts),
          if (max(counts) == 1L) "" else "s"
        ),
        group = group,
        call = call
      )
    }
    return(ifelse(group <= counts, as.integer(group), -1L))
  }
  zuregex_abort(
    "argument",
    sprintf(
      "`group` must be a whole number of 0 or more, or a group name, not %s.",
      describe(group)
    ),
    call = call
  )
}

match_groups <- function(x, pattern, all, n, limits, call) {
  s <- subjects(x, call)
  p <- patterns(pattern, s$n, s$bytes, call)
  layout <- group_layout(table_groups(p$table))
  cols <- run_verb(
    .Call(
      zuregex_match_c,
      s$x,
      s$bytes,
      p$table,
      p$index,
      call_limits(limits, call),
      layout$colmap,
      length(layout$names),
      all,
      as.double(n),
      FALSE
    ),
    call
  )
  names(cols) <- c(if (all) c("element", "match"), layout$names)
  # A pattern with no groups gives no columns, so the rows are counted here.
  as_data_frame(cols, n = if (all) length(cols$element) else s$n)
}

# The columns of re_match() for a table of patterns (design section 6.5): a
# named group's column is its name, an unnamed group's its position; the
# union keeps the order of first appearance. colmap gives, per pattern, the
# column of each of its groups.
group_layout <- function(groups) {
  keys <- lapply(groups, function(g) {
    ifelse(nzchar(g), g, as.character(seq_along(g)))
  })
  names <- unique(unlist(keys, use.names = FALSE))
  if (is.null(names)) {
    names <- character()
  }
  colmap <- lapply(keys, function(k) match(k, names))
  list(names = names, colmap = colmap)
}

# utils::strcapture()'s conformToProto(), without its S4 branch, which
# would need the methods package.
conform_to_proto <- function(df, proto, call) {
  proto <- as.list(proto)
  if (length(proto) != ncol(df)) {
    zuregex_abort(
      "argument",
      sprintf(
        "`proto` has %d element%s, but the pattern has %d group%s.",
        length(proto),
        if (length(proto) == 1L) "" else "s",
        ncol(df),
        if (ncol(df) == 1L) "" else "s"
      ),
      call = call
    )
  }
  out <- lapply(seq_along(proto), function(i) {
    if (isS4(proto[[i]])) {
      zuregex_abort(
        "argument",
        "`proto` columns with S4 classes are not supported.",
        call = call
      )
    }
    convert <- match.fun(paste0("as.", class(proto[[i]])[[1L]]))
    convert(df[[i]])
  })
  names(out) <- names(proto)
  as_data_frame(out, n = nrow(df))
}

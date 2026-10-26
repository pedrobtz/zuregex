#' Replace matches
#'
#' `re_replace()` replaces matches in each element of `x`, all of them by
#' default. `re_expand()` returns a template expanded with each element's
#' first match, as Python's `Match.expand()` does.
#'
#' @section Templates:
#' With `syntax = "extended"`, the default, templates use PCRE2's extended
#' substitution syntax, not base R's `\\1`:
#'
#' | Template | Meaning |
#' | --- | --- |
#' | `$1`, `${12}`, `${name}` | A group by number, past nine, or by name. `$0` is the whole match. |
#' | `${1:-none}` | The group, or `none` when it did not take part in the match. |
#' | `${1:+yes:no}` | `yes` when the group took part, otherwise `no`. |
#' | `\U...\E`, `\L...\E`, `\u`, `\l` | Upper or lower case until `\E`, or for one character. |
#' | `$$`, `\$` | A literal `$`. |
#'
#' A group that did not take part in the match is replaced by `""`. A
#' reference to a group that does not exist, or a malformed template,
#' raises `zuregex_error_template` when a match first uses it. With
#' `syntax = "literal"` the replacement is inserted as it is.
#'
#' @section Replacement functions:
#' `replacement` may be a function. It is called once for the whole call,
#' if anything matched, with a data frame of every match: `element`,
#' `match` (its number within the element), `0` (the matched text) and one
#' column per group, named as in [re_match()]. A group named `element`,
#' `match` or `0` repeats that column's name, as in [re_match_all()]. It must
#' return a character vector with one replacement per row.
#'
#' @inheritParams re_locate
#' @inheritSection re_detect Patterns
#' @inheritSection re_detect Strings and bytes
#' @param replacement A character vector of templates, of length 1 or the
#'   length of `x`, or a function; see Templates and Replacement functions.
#'   An `NA` template gives `NA`.
#' @param n The most matches to replace per element, `Inf` for all.
#' @param syntax `"extended"` or `"literal"`; see Templates.
#' @param template A character vector of templates, of length 1 or the
#'   length of `x`.
#' @return A character vector as long as `x`. Elements without a match are
#'   returned unchanged by `re_replace()` and as `NA` by `re_expand()`.
#'   Other strings are in UTF-8, or marked as `"bytes"` for bytes input.
#' @export
#' @examples
#' x <- c("2026-10-21", "no date", NA)
#' re_replace(x, "(\\d{4})-(\\d{2})-(\\d{2})", "$3/$2/$1")
#' re_replace(x, "(?<y>\\d{4})", "${y}!")
#' re_replace("hello world", "(\\w+)", "\\u$1")
#' re_replace("a1b22", "\\d+", function(m) strrep("#", nchar(m[["0"]])))
#' re_expand("John Smith", "(\\w+) (\\w+)", "$2, $1")
re_replace <- function(
  x,
  pattern,
  replacement,
  n = Inf,
  syntax = c("extended", "literal"),
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
  if (missing(syntax)) {
    syntax <- "extended"
  } else {
    check_choice(syntax, c("extended", "literal"), "syntax", call)
  }
  lim <- verb_limits(limits, call)
  if (
    is.character(x) &&
      is.character(pattern) &&
      length(pattern) == 1L &&
      is.character(replacement) &&
      length(replacement) == 1L
  ) {
    out <- withCallingHandlers(
      .Call(
        zuregex_replace_c,
        x,
        NA,
        pattern,
        opts,
        lim,
        replacement,
        0L,
        syntax == "literal",
        as.double(n),
        FALSE,
        NULL
      ),
      error = function(e) native_error(e, call)
    )
    if (!is.null(out)) {
      return(
        if (is.object(out)) {
          fast_result(out, call, pattern, replacement, opts = opts)
        } else {
          out
        }
      )
    }
  }
  prep <- native(prepare(x, pattern, call, opts), call)
  if (is.function(replacement)) {
    return(replace_with_function(prep, replacement, n, lim, call))
  }
  check_templates(replacement, "replacement", prep$n, call, prep$bytes)
  run_replace(
    prep,
    lim,
    enc2utf8(replacement),
    0L,
    syntax == "literal",
    n,
    FALSE,
    call
  )
}

#' @rdname re_replace
#' @export
re_expand <- function(
  x,
  pattern,
  template,
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
  lim <- verb_limits(limits, call)
  if (
    is.character(x) &&
      is.character(pattern) &&
      length(pattern) == 1L &&
      is.character(template) &&
      length(template) == 1L
  ) {
    out <- withCallingHandlers(
      .Call(
        zuregex_replace_c,
        x,
        NA,
        pattern,
        opts,
        lim,
        template,
        0L,
        FALSE,
        1,
        TRUE,
        NULL
      ),
      error = function(e) native_error(e, call)
    )
    if (!is.null(out)) {
      return(
        if (is.object(out)) {
          fast_result(out, call, pattern, template, opts = opts)
        } else {
          out
        }
      )
    }
  }
  prep <- native(prepare(x, pattern, call, opts), call)
  check_templates(template, "template", prep$n, call, prep$bytes)
  run_replace(
    prep,
    lim,
    enc2utf8(template),
    0L,
    FALSE,
    1,
    TRUE,
    call
  )
}

check_templates <- function(x, arg, n, call, bytes = FALSE) {
  if (!is.character(x)) {
    zuregex_abort(
      "argument",
      sprintf(
        "`%s` must be a character vector or a function, not %s.",
        arg,
        describe(x)
      ),
      call = call
    )
  }
  if (any(Encoding(x) == "bytes") && !bytes) {
    zuregex_abort(
      "argument",
      sprintf(
        "`%s` is marked as \"bytes\", so `x` must be bytes too: a raw vector, or strings marked as \"bytes\".",
        arg
      ),
      call = call
    )
  }
  if (length(x) != 1L && length(x) != n) {
    zuregex_abort(
      "length",
      sprintf(
        "`%s` must have length 1 or the length of `x` (%d), not %d.",
        arg,
        n,
        length(x)
      ),
      call = call
    )
  }
}

run_replace <- function(
  prep,
  lim,
  repl,
  mode,
  literal,
  n,
  expand,
  call,
  first = NULL
) {
  res <- native(
    .Call(
      zuregex_replace_c,
      prep$x,
      prep$bytes,
      prep$table,
      prep$index,
      lim,
      repl,
      mode,
      literal,
      as.double(n),
      expand,
      first
    ),
    call
  )
  if (!is.null(res$error) && res$error$kind == "template") {
    raise_template_error(res$error, repl, call)
  }
  verb_result(res, call)
}

raise_template_error <- function(err, repl, call) {
  element <- err$element
  tmpl <- if (length(repl) == 1L) repl[[1L]] else repl[[element]]
  # PCRE2 reports a byte offset into the template; count characters.
  bytes <- charToRaw(tmpl)
  upto <- bytes[seq_len(min(err$offset - 1, length(bytes)))]
  position <- nchar(rawToChar(upto), type = "chars", allowNA = TRUE) + 1L
  shown <- pattern_window(tmpl, position)
  before <- substr(shown$text, 1L, shown$caret - 1L)
  caret <- paste0(strrep(" ", nchar(before, type = "width")), "^")
  zuregex_abort(
    "template",
    paste0(
      sprintf(
        "Can't expand the replacement template for element %s: %s at character %d.\n",
        format(element, scientific = FALSE),
        err$message,
        position
      ),
      "  ",
      shown$text,
      "\n  ",
      caret
    ),
    template = tmpl,
    element = element,
    position = position,
    pcre2_message = err$message,
    call = call
  )
}

replace_with_function <- function(prep, fun, n, lim, call) {
  layout <- group_layout(table_groups(prep$table))
  # The matches with the whole match as group 0, from the same iteration as
  # the replacement pass below. Elements that hit a limit here are NA and
  # skipped there, so this pass's limit warning is the call's one warning,
  # raised once the replacement is done.
  limit_warning <- NULL
  zero <- lapply(layout$colmap, function(m) c(1L, m + 1L))
  cols <- withCallingHandlers(
    run_verb(
      .Call(
        zuregex_match_c,
        prep$x,
        prep$bytes,
        prep$table,
        prep$index,
        lim,
        zero,
        length(layout$names) + 1L,
        TRUE,
        as.double(n),
        TRUE
      ),
      call
    ),
    zuregex_warning_limit = function(w) {
      limit_warning <<- w
      invokeRestart("muffleWarning")
    }
  )
  names(cols) <- c("element", "match", "0", layout$names)
  matches <- as_data_frame(cols)
  # Each element's first row, 0-based, for the replacement pass; NA where
  # the element gives NA (an NA subject or pattern, or a limit).
  na_rows <- is.na(matches$match)
  first <- rep(0L, prep$n)
  first[matches$element[na_rows]] <- NA_integer_
  matches <- matches[!na_rows, , drop = FALSE]
  rownames(matches) <- NULL
  counts <- tabulate(matches$element, nbins = prep$n)
  ok <- !is.na(first)
  first[ok] <- c(0L, cumsum(counts))[seq_len(prep$n)][ok]
  repl <- character()
  if (nrow(matches) > 0L) {
    repl <- fun(matches)
    if (!is.character(repl) || length(repl) != nrow(matches)) {
      zuregex_abort(
        "argument",
        sprintf(
          "The replacement function must return a character vector of length %d, one per match, not %s.",
          nrow(matches),
          describe(repl)
        ),
        call = call
      )
    }
  }
  out <- run_replace(
    prep,
    lim,
    enc2utf8(repl),
    1L,
    TRUE,
    n,
    FALSE,
    call,
    first = as.integer(first)
  )
  if (!is.null(limit_warning)) {
    warning(limit_warning)
  }
  out
}

#' Split strings
#'
#' Splits each element of `x` at the matches of `pattern`, as Python's
#' `re.split()` does: an empty match splits too, and with
#' `keep_groups = TRUE` each separator's groups are kept between the pieces.
#'
#' @inheritParams re_locate
#' @inheritSection re_detect Patterns
#' @inheritSection re_detect Strings and bytes
#' @param n The most pieces per element, `Inf` for no limit. The last piece
#'   holds the rest of the string, as with Go's `Split(n)`; `n = 0` gives no
#'   pieces.
#' @param keep_groups If `TRUE`, the groups of each separator are inserted
#'   after the piece before it, `NA` for a group that did not take part.
#' @return A list as long as `x` of character vectors; `NA` for an `NA`
#'   subject or pattern.
#' @export
#' @examples
#' re_split(c("a, b,c", "d"), ",\\s*")
#' re_split("a1b22c", "(\\d+)", keep_groups = TRUE)
#' re_split("a-b-c-d", "-", n = 2)
re_split <- function(
  x,
  pattern,
  n = Inf,
  keep_groups = FALSE,
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
  if (
    !is.logical(keep_groups) || length(keep_groups) != 1L || is.na(keep_groups)
  ) {
    check_flag(keep_groups, "keep_groups", call)
  }
  lim <- verb_limits(limits, call)
  out <- NULL
  if (is.character(x) && is.character(pattern) && length(pattern) == 1L) {
    out <- withCallingHandlers(
      .Call(
        zuregex_split_c,
        x,
        NA,
        pattern,
        opts,
        lim,
        as.double(max(n - 1, 0)),
        keep_groups
      ),
      error = function(e) native_error(e, call)
    )
    if (is.object(out)) {
      out <- fast_result(out, call, pattern, opts = opts)
    }
  }
  if (is.null(out)) {
    out <- run_verb(
      {
        prep <- prepare(x, pattern, call, opts)
        .Call(
          zuregex_split_c,
          prep$x,
          prep$bytes,
          prep$table,
          prep$index,
          lim,
          as.double(max(n - 1, 0)),
          keep_groups
        )
      },
      call
    )
  }
  if (n == 0) {
    out <- lapply(out, function(v) {
      if (length(v) == 1L && is.na(v)) v else character()
    })
  }
  out
}

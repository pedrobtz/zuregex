#' Compile regular expressions
#'
#' `re_compile()` compiles each pattern once, with PCRE2's just-in-time
#' compiler where the platform allows it, and returns an `re` vector that
#' every `re_*()` function accepts in place of a character pattern.
#' Compilation goes through the pattern cache, so compiling the same pattern
#' again is cheap; see [re_cache_size()].
#'
#' @param pattern A character vector of regular expressions. `NA` gives an
#'   `NA` element.
#' @param flags A single string of flag letters, applied to every pattern:
#'
#'   | Letter | Meaning |
#'   | --- | --- |
#'   | `i` | Case-insensitive. |
#'   | `m` | `^` and `$` match at line boundaries. |
#'   | `s` | `.` matches a newline. |
#'   | `x` | Ignore whitespace and allow `#` comments. |
#'   | `xx` | As `x`, and also ignore whitespace inside character classes. |
#'   | `n` | Only named groups capture. |
#'   | `U` | Quantifiers are lazy unless followed by `?`. |
#'   | `J` | Groups may share a name. |
#'   | `u` | `\w`, `\d`, `\b` and POSIX classes follow Unicode properties. |
#'   | `r` | No case equivalence between ASCII and non-ASCII characters. |
#'   | `aD`, `aS`, `aW` | Keep `\d`, `\s` or `\w` ASCII under `u`. |
#'   | `aT`, `aP` | Keep POSIX digit classes, or all POSIX classes, ASCII under `u`. |
#'   | `a` | All five `a` restrictions. |
#'
#'   Each letter may appear once, and `x` and `xx` exclude each other.
#' @param dialect `"pcre"`, the default, compiles patterns as base R's
#'   `perl = TRUE` does. `"js"` adds the options node-pcre2 uses for
#'   JavaScript patterns: `\u` escapes, `$` only at the very end, and
#'   unset back-references that match the empty string.
#' @param literal If `TRUE`, each pattern is matched as a literal string,
#'   with no metacharacters. Only the flags `i` and `r` apply to a literal.
#' @param jit If `TRUE`, JIT-compile each pattern when the platform allows
#'   it. If JIT compilation fails, the interpreter is used and
#'   `re_info()$jit` is `FALSE`.
#' @return An `re` vector, as long as `pattern`.
#' @seealso [re_info()] to inspect compiled patterns, [re_escape()] to quote
#'   metacharacters.
#' @export
#' @examples
#' re <- re_compile(c("(\\d+)-(\\d+)", "^[a-z]+$"), flags = "i")
#' re
#' re_info(re)
#'
#' # A literal pattern needs no escaping
#' re_compile("1+1=2", literal = TRUE)
re_compile <- function(
  pattern,
  flags = "",
  dialect = c("pcre", "js"),
  literal = FALSE,
  jit = TRUE
) {
  if (missing(dialect)) {
    dialect <- "pcre"
  }
  # One cheap test for the common case; the checks that build an error
  # message run only when it fails. A cache hit is about a microsecond in C,
  # so the R code around it is most of the cost of re_compile().
  if (
    !is.character(pattern) ||
      !is_string(flags) ||
      Encoding(flags) == "bytes" ||
      !is_string(dialect) ||
      !(dialect == "pcre" || dialect == "js") ||
      !is_bool(literal) ||
      !is_bool(jit)
  ) {
    call <- sys.call()
    if (!is.character(pattern)) {
      zuregex_abort(
        "argument",
        sprintf(
          "`pattern` must be a character vector, not %s.",
          describe(pattern)
        ),
        call = call
      )
    }
    check_flags(flags, call)
    check_choice(dialect, c("pcre", "js"), "dialect", call)
    check_flag(literal, "literal", call)
    check_flag(jit, "jit", call)
  }
  out <- compile_patterns(
    unname(enc2utf8(pattern)),
    flags,
    dialect,
    literal,
    jit
  )
  names(out) <- names(pattern)
  out
}

is_string <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x)
}

is_bool <- function(x) {
  is.logical(x) && length(x) == 1L && !is.na(x)
}

compile_patterns <- function(
  pattern,
  flags,
  dialect,
  literal,
  jit,
  call = sys.call(-1L),
  utf = TRUE,
  use_cache = TRUE
) {
  res <- native(
    .Call(
      zuregex_compile_c,
      pattern,
      flags,
      if (dialect == "js") 1L else 0L,
      literal,
      jit,
      utf,
      use_cache
    ),
    call
  )
  if (!is.null(res$error)) {
    raise_compile_error(res$error, pattern, flags, literal, call)
  }
  ptrs <- res$value
  attributes(ptrs) <- list(
    pattern = pattern,
    flags = flags,
    dialect = dialect,
    literal = literal,
    jit = jit,
    class = "re"
  )
  ptrs
}

raise_compile_error <- function(err, pattern, flags, literal, call) {
  if (err$kind == "flags") {
    letter <- substr(flags, err$offset, err$offset)
    why <- if (literal) {
      "is unknown, repeated, or not allowed with `literal = TRUE` (only `i` and `r` are)"
    } else {
      "is unknown or repeated"
    }
    zuregex_abort(
      "flags",
      sprintf(
        "Flag `%s` at position %d of `flags = \"%s\"` %s.",
        letter,
        err$offset,
        flags,
        why
      ),
      flags = flags,
      position = err$offset,
      call = call
    )
  }
  bad <- pattern[[err$element]]
  where <- if (length(pattern) > 1L) {
    sprintf(" %d", err$element)
  } else {
    ""
  }
  shown <- pattern_window(bad, err$offset)
  before <- substr(shown$text, 1L, shown$caret - 1L)
  caret <- paste0(strrep(" ", nchar(before, type = "width")), "^")
  zuregex_abort(
    "compile",
    paste0(
      sprintf(
        "Can't compile pattern%s: %s at character %d.\n",
        where,
        err$message,
        err$offset
      ),
      "  ",
      shown$text,
      "\n  ",
      caret
    ),
    pattern = bad,
    element = err$element,
    offset = err$offset,
    pcre2_message = err$message,
    call = call
  )
}

# At most `width` characters of a pattern around `offset`, with "..." where
# it is cut, so a compile error in a long pattern stays readable. Returns
# the text and the caret's position in it.
pattern_window <- function(pattern, offset, width = 60L) {
  n <- nchar(pattern)
  if (n <= width) {
    return(list(text = pattern, caret = offset))
  }
  from <- max(1L, offset - width %/% 2L)
  to <- min(n, from + width - 1L)
  from <- max(1L, to - width + 1L)
  text <- substr(pattern, from, to)
  caret <- offset - from + 1L
  if (from > 1L) {
    text <- paste0("...", text)
    caret <- caret + 3L
  }
  if (to < n) {
    text <- paste0(text, "...")
  }
  list(text = text, caret = caret)
}

# An `re` whose external pointers did not survive serialization (saveRDS(),
# a parallel worker) is recompiled from its attributes, so it keeps working.
re_restore <- function(re) {
  valid <- .Call(zuregex_re_valid_c, re)
  stale <- !valid & !is.na(attr(re, "pattern"))
  if (any(stale)) {
    fresh <- compile_patterns(
      attr(re, "pattern")[stale],
      attr(re, "flags"),
      attr(re, "dialect"),
      attr(re, "literal"),
      attr(re, "jit"),
      call = NULL
    )
    attrs <- attributes(re)
    re <- unclass(re)
    re[stale] <- unclass(fresh)
    attributes(re) <- attrs
  }
  re
}

# An `re` object's attributes are read by C and by re_restore(); an object
# edited by hand is refused with a class rather than failing inside.
check_re_attributes <- function(re, call) {
  a <- attributes(re)
  ok <- is.character(a$pattern) &&
    length(a$pattern) == length(re) &&
    is_string(a$flags) &&
    is_string(a$dialect) &&
    a$dialect %in% c("pcre", "js") &&
    is_bool(a$literal) &&
    is_bool(a$jit)
  if (!ok) {
    zuregex_abort(
      "argument",
      "This `re` object has been modified: its attributes are not what `re_compile()` makes.",
      call = call
    )
  }
}

check_re <- function(re, arg, call) {
  if (!inherits(re, "re")) {
    zuregex_abort(
      "argument",
      sprintf(
        "`%s` must be an `re` object from `re_compile()`, not %s.",
        arg,
        describe(re)
      ),
      call = call
    )
  }
}

#' @export
format.re <- function(x, ...) {
  pattern <- attr(x, "pattern")
  out <- paste0("/", pattern, "/", attr(x, "flags"))
  if (isTRUE(attr(x, "literal"))) {
    out <- paste(out, "(literal)")
  }
  if (identical(attr(x, "dialect"), "js")) {
    out <- paste(out, "(js)")
  }
  out[is.na(pattern)] <- NA_character_
  out
}

#' @export
print.re <- function(x, ...) {
  cat(sprintf("<re[%d]>\n", length(x)))
  if (length(x) > 0L) {
    # cat(), not print(): print() would show each backslash doubled.
    lines <- format(x)
    lines[is.na(lines)] <- "<NA>"
    labels <- format(sprintf("[%d]", seq_along(lines)), justify = "right")
    cat(paste(labels, lines), sep = "\n")
  }
  invisible(x)
}

#' @export
as.character.re <- function(x, ...) {
  attr(x, "pattern")
}

# The attributes two re vectors must share to be combined: one set of
# flags, dialect, literal and jit applies to every element.
re_settings <- function(x) {
  attributes(x)[c("flags", "dialect", "literal", "jit")]
}

check_same_settings <- function(x, value, call) {
  if (!inherits(value, "re")) {
    zuregex_abort(
      "argument",
      sprintf(
        "Only an `re` object can go into an `re` vector, not %s.",
        describe(value)
      ),
      call = call
    )
  }
  if (!identical(re_settings(x), re_settings(value))) {
    zuregex_abort(
      "argument",
      "`re` objects can be combined only when they share flags, dialect, `literal` and `jit`.",
      call = call
    )
  }
}

# The positions `i` selects in `x`, by number, name or logical.
re_index <- function(x, i) {
  idx <- seq_along(x)
  names(idx) <- names(x)
  idx[i]
}

#' @export
`[<-.re` <- function(x, i, value) {
  call <- sys.call()
  check_same_settings(x, value, call)
  attrs <- attributes(x)
  pattern <- attrs$pattern
  ptrs <- unclass(x)
  idx <- re_index(x, i)
  if (anyNA(idx)) {
    zuregex_abort(
      "argument",
      "An `re` vector can't grow by assignment; use `c()` to add patterns.",
      call = call
    )
  }
  ptrs[idx] <- rep_len(unclass(value), length(idx))
  pattern[idx] <- rep_len(attr(value, "pattern"), length(idx))
  attrs$pattern <- pattern
  attributes(ptrs) <- attrs
  ptrs
}

#' @export
`[[.re` <- function(x, i) {
  idx <- if (length(i) == 1L) re_index(x, i) else NA
  if (anyNA(idx)) {
    zuregex_abort(
      "argument",
      "`[[` takes one element of an `re` vector that exists.",
      call = sys.call()
    )
  }
  x[idx]
}

#' @export
`[[<-.re` <- function(x, i, value) {
  if (length(value) != 1L) {
    zuregex_abort(
      "argument",
      "`[[<-` takes an `re` object of length 1.",
      call = sys.call()
    )
  }
  x[i] <- value
  x
}

#' @export
c.re <- function(...) {
  parts <- list(...)
  for (p in parts[-1]) {
    check_same_settings(parts[[1L]], p, sys.call())
  }
  out <- unlist(lapply(parts, unclass), recursive = FALSE)
  attrs <- attributes(parts[[1L]])
  attrs$pattern <- unlist(lapply(parts, attr, "pattern"), use.names = FALSE)
  attrs$names <- names(out)
  attributes(out) <- attrs
  out
}

#' @export
rep.re <- function(x, ...) {
  x[rep(seq_along(x), ...)]
}

#' @export
`[.re` <- function(x, i) {
  attrs <- attributes(x)
  pattern <- attrs$pattern
  names(pattern) <- NULL
  idx <- re_index(x, i)
  out <- unclass(x)[idx]
  attrs$pattern <- pattern[idx]
  attrs$names <- names(out)
  attributes(out) <- attrs
  out
}

#' Describe compiled patterns
#'
#' Reports what PCRE2 recorded when it compiled each pattern.
#'
#' @param re An `re` vector from [re_compile()].
#' @return A data frame with one row per pattern and columns:
#'   * `pattern`, `flags`, `dialect`, `literal`: what was compiled. `flags`
#'     is rebuilt from PCRE2's options, in a canonical order.
#'   * `groups`: the number of capture groups.
#'   * `group_names`: a list column; for each pattern, a character vector
#'     with one name per group, `""` for unnamed groups.
#'   * `jit`: whether the pattern runs JIT-compiled code.
#'   * `min_length`: a lower bound on the length of a match, in characters.
#'   * `prefix`: a literal string every match starts with, `""` when there
#'     is none or it cannot be determined simply. It may be shorter than the
#'     longest such string.
#'   * `backrefs`: whether the pattern has back-references.
#'   * `pcre2_version`: the PCRE2 version that compiled it.
#'
#'   An `NA` pattern gives a row of `NA`.
#' @export
#' @examples
#' re_info(re_compile(c("(?<year>\\d{4})-(\\d{2})", "abc+")))
re_info <- function(re) {
  check_re(re, "re", sys.call())
  check_re_attributes(re, sys.call())
  re <- re_restore(re)
  cols <- .Call(zuregex_re_info_c, re)
  prefix <- mapply(
    literal_prefix,
    cols$pattern,
    cols$flags,
    cols$literal,
    USE.NAMES = FALSE
  )
  version <- zuregex_info()$pcre2_version
  out <- data.frame(
    pattern = cols$pattern,
    flags = cols$flags,
    dialect = cols$dialect,
    literal = cols$literal,
    groups = cols$groups,
    jit = cols$jit,
    min_length = cols$min_length,
    prefix = as.character(prefix),
    backrefs = cols$backrefs,
    pcre2_version = ifelse(is.na(cols$pattern), NA_character_, version),
    stringsAsFactors = FALSE
  )
  out$group_names <- cols$group_names
  out[c(
    "pattern",
    "flags",
    "dialect",
    "literal",
    "groups",
    "group_names",
    "jit",
    "min_length",
    "prefix",
    "backrefs",
    "pcre2_version"
  )]
}

# A literal string every match of `pattern` starts with, found by reading
# the pattern's leading literal characters. Conservative: anything that
# could change what the leading characters match ends the prefix, and a
# top-level alternation, case-insensitivity or extended mode gives "".
literal_prefix <- function(pattern, flags, literal) {
  if (is.na(pattern)) {
    return(NA_character_)
  }
  if (grepl("i", flags, fixed = TRUE)) {
    return("")
  }
  if (literal) {
    return(pattern)
  }
  if (grepl("x", flags, fixed = TRUE) || has_top_level_bar(pattern)) {
    return("")
  }
  chars <- strsplit(pattern, "", fixed = TRUE)[[1]]
  atoms <- character()
  i <- 1L
  n <- length(chars)
  while (i <= n) {
    ch <- chars[[i]]
    if (ch == "\\") {
      nxt <- if (i < n) chars[[i + 1L]] else ""
      # An escaped ASCII punctuation character is that character; any other
      # escape is a class, an anchor, a reference or a code point.
      if (!grepl("^[[:punct:]]$", nxt) || grepl("[^\x01-\x7f]", nxt)) {
        break
      }
      atoms <- c(atoms, nxt)
      i <- i + 2L
      next
    }
    if (ch %in% c("*", "+", "?", "{")) {
      # A quantifier applies to the previous atom, which is then not
      # certain to appear exactly once.
      atoms <- atoms[-length(atoms)]
      break
    }
    if (ch %in% c(".", "^", "$", "(", ")", "[", "]", "|")) {
      break
    }
    atoms <- c(atoms, ch)
    i <- i + 1L
  }
  paste(atoms, collapse = "")
}

has_top_level_bar <- function(pattern) {
  chars <- strsplit(pattern, "", fixed = TRUE)[[1]]
  depth <- 0L
  in_class <- FALSE
  i <- 1L
  while (i <= length(chars)) {
    ch <- chars[[i]]
    if (ch == "\\") {
      i <- i + 2L
      next
    }
    if (in_class) {
      if (ch == "]") in_class <- FALSE
    } else if (ch == "[") {
      in_class <- TRUE
      # A ] right after [ or [^ is a literal member, not the end.
      if (i < length(chars) && chars[[i + 1L]] == "^") {
        i <- i + 1L
      }
      if (i < length(chars) && chars[[i + 1L]] == "]") i <- i + 1L
    } else if (ch == "(") {
      depth <- depth + 1L
    } else if (ch == ")") {
      depth <- depth - 1L
    } else if (ch == "|" && depth == 0L) {
      return(TRUE)
    }
    i <- i + 1L
  }
  FALSE
}

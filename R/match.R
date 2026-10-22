# What every matching verb does before calling C: check `x`, decide between
# UTF-8 and bytes, apply the pairing rule to `pattern` (design section 6.5,
# D8) and compile each distinct pattern once.

# subjects() and patterns() in one step: list(x, n, bytes, table, index).
# A character vector with one pattern string, the common case, takes one
# .Call; anything else goes through the two R functions below. Call it
# inside run_verb() or native(), which class the errors its .Call can
# raise; a verb then pays for one handler, not two.
# `opts` is NULL for the default flags and literal, or what
# pattern_options() returns.
prepare <- function(x, pattern, call, opts = NULL) {
  flags <- if (is.null(opts)) "" else opts[[1L]]
  literal <- if (is.null(opts)) FALSE else opts[[2L]]
  res <- .Call(zuregex_prepare_c, x, pattern, flags, literal)
  if (is.null(res)) {
    s <- subjects(x, call)
    p <- patterns(pattern, s$n, s$bytes, call, opts)
    return(list(
      x = s$x,
      n = s$n,
      bytes = s$bytes,
      table = p$table,
      index = p$index
    ))
  }
  if (!is.null(res$error)) {
    raise_compile_error(res$error, pattern, flags, literal, call)
  }
  res
}

# A verb's `flags` and `literal`, checked, as list(flags, literal): what the
# fast path's .Call and prepare() take. Verbs call it only when one of the
# two was given, and pass NULL otherwise.
pattern_options <- function(flags, literal, call) {
  # One cheap test for valid input; the checks that build a message run
  # only when it fails. A verb with flags is otherwise a few microseconds.
  if (
    is.character(flags) &&
      length(flags) == 1L &&
      !is.na(flags) &&
      Encoding(flags) != "bytes" &&
      is.logical(literal) &&
      length(literal) == 1L &&
      !is.na(literal)
  ) {
    return(list(flags, literal))
  }
  check_string(flags, "flags", call)
  if (Encoding(flags) == "bytes") {
    zuregex_abort(
      "argument",
      "`flags` must not be marked as \"bytes\".",
      call = call
    )
  }
  check_flag(literal, "literal", call)
  list(flags, literal)
}

# x: a character vector, a raw vector (one subject) or a list of raw
# vectors. Returns list(x, n, bytes).
subjects <- function(x, call) {
  # Element numbers and offsets come back as R integers.
  if (length(x) > .Machine$integer.max) {
    zuregex_abort(
      "argument",
      "`x` may have at most 2^31 - 1 elements.",
      call = call
    )
  }
  if (is.raw(x) && length(x) > .Machine$integer.max) {
    zuregex_abort(
      "argument",
      "A raw subject may have at most 2^31 - 1 bytes.",
      call = call
    )
  }
  if (is.list(x) && any(lengths(x) > .Machine$integer.max)) {
    zuregex_abort(
      "argument",
      "A raw subject may have at most 2^31 - 1 bytes.",
      call = call
    )
  }
  if (is.character(x)) {
    bytes <- .Call(zuregex_has_bytes_c, x)
    return(list(x = x, n = length(x), bytes = bytes))
  }
  if (is.raw(x)) {
    return(list(x = x, n = 1L, bytes = TRUE))
  }
  if (
    is.list(x) && all(vapply(x, function(el) is.raw(el) || is.null(el), TRUE))
  ) {
    return(list(x = x, n = length(x), bytes = TRUE))
  }
  zuregex_abort(
    "argument",
    sprintf(
      "`x` must be a character vector, a raw vector or a list of raw vectors, not %s.",
      describe(x)
    ),
    call = call
  )
}

# Resolves `pattern` for `n` subjects. Returns list(table, index): `table`
# holds the call's distinct compiled patterns and `index` the 1-based entry
# for each subject (one entry when the pattern is shared), NA for an NA
# pattern.
patterns <- function(pattern, n, bytes, call, opts = NULL) {
  len <- length(pattern)
  if (len != 1L && len != n) {
    zuregex_abort(
      "length",
      sprintf(
        "`pattern` must have length 1 or the length of `x` (%d), not %d.",
        n,
        len
      ),
      call = call
    )
  }
  if (inherits(pattern, "re")) {
    if (!is.null(opts)) {
      zuregex_abort(
        "argument",
        "`flags` and `literal` apply to pattern strings; an `re` object carries its own from `re_compile()`.",
        call = call
      )
    }
    return(re_patterns(pattern, bytes, call))
  }
  flags <- if (is.null(opts)) "" else opts[[1L]]
  literal <- if (is.null(opts)) FALSE else opts[[2L]]
  if (len == 1L && is.character(pattern) && !is.na(pattern)) {
    # The common case, one pattern string: a cache lookup in C, without
    # unique(), match() or the attributes of an `re` object.
    pattern <- enc2utf8(pattern)
    res <- native(
      .Call(zuregex_compile_c, pattern, flags, 0L, literal, TRUE, !bytes, TRUE),
      call
    )
    if (!is.null(res$error)) {
      raise_compile_error(res$error, pattern, flags, literal, call)
    }
    return(list(table = res$value, index = 1L))
  }
  if (!is.character(pattern)) {
    zuregex_abort(
      "argument",
      sprintf(
        "`pattern` must be a character vector or an `re` object, not %s.",
        describe(pattern)
      ),
      call = call
    )
  }
  pattern <- enc2utf8(pattern)
  distinct <- unique(pattern[!is.na(pattern)])
  # More distinct patterns than the cache holds are compiled for this call
  # only, so one call does not flush the cache for everything else.
  use_cache <- length(distinct) <= re_cache_size()
  table <- compile_patterns(
    distinct,
    flags,
    "pcre",
    literal,
    TRUE,
    call = call,
    utf = !bytes,
    use_cache = use_cache
  )
  list(table = unclass(table), index = match(pattern, distinct))
}

re_patterns <- function(re, bytes, call) {
  check_re_attributes(re, call)
  re <- re_restore(re)
  index <- seq_along(re)
  index[is.na(attr(re, "pattern"))] <- NA_integer_
  if (bytes) {
    # An `re` is compiled for UTF-8; bytes need the same pattern without it.
    keep <- !is.na(attr(re, "pattern"))
    table <- compile_patterns(
      attr(re, "pattern")[keep],
      attr(re, "flags"),
      attr(re, "dialect"),
      attr(re, "literal"),
      attr(re, "jit"),
      call = call,
      utf = FALSE
    )
    index[keep] <- seq_len(sum(keep))
    return(list(table = unclass(table), index = index))
  }
  table <- unclass(re)
  table[is.na(index)] <- list(NULL)
  table <- table[!is.na(index)]
  index[!is.na(index)] <- seq_along(table)
  list(table = table, index = index)
}

# Turns the error description a C verb returns into a condition.
raise_match_error <- function(err, call) {
  element <- err$element
  if (err$kind == "utf") {
    zuregex_abort(
      "utf",
      sprintf(
        "Element %s of `x` is not valid UTF-8 at byte %s: %s.",
        format(element, scientific = FALSE),
        format(err$offset, scientific = FALSE),
        err$message
      ),
      element = element,
      byte = err$offset,
      pcre2_message = err$message,
      call = call
    )
  }
  if (err$kind == "limit") {
    limit <- switch(
      as.character(err$rc),
      "-47" = "match",
      "-53" = "depth",
      "-63" = "heap",
      "-46" = "jit_stack",
      "unknown"
    )
    zuregex_abort(
      "limit",
      sprintf(
        "Element %s of `x` hit the %s limit: %s. See `?re_limits`.",
        format(element, scientific = FALSE),
        limit,
        err$message
      ),
      element = element,
      limit = limit,
      pcre2_message = err$message,
      call = call
    )
  }
  zuregex_abort(
    "match",
    sprintf(
      "Matching element %s of `x` failed: %s.",
      format(element, scientific = FALSE),
      err$message
    ),
    element = element,
    pcre2_code = err$rc,
    pcre2_message = err$message,
    call = call
  )
}

# The fast path: a verb's .Call given `x` and one pattern string, which
# returns the value itself, NULL when the call needs the general path, or
# a "zuregex_result" list when something went wrong. fast_result() turns
# that list into its error or warning.
fast_result <- function(res, call, pattern, repl = NULL, opts = NULL) {
  err <- res$error
  if (!is.null(err) && err$kind %in% c("compile", "flags")) {
    raise_compile_error(
      err,
      pattern,
      if (is.null(opts)) "" else opts[[1L]],
      if (is.null(opts)) FALSE else opts[[2L]],
      call
    )
  }
  if (!is.null(err) && err$kind == "template") {
    raise_template_error(err, repl, call)
  }
  verb_result(res, call)
}

# The calling handler every .Call runs under (see native()).
native_error <- function(e, call) {
  if (!inherits(e, "zuregex_error")) {
    zuregex_abort("native", conditionMessage(e), parent = e, call = call)
  }
}

# Evaluates `res`, a verb's .Call and whatever prepares it, under one
# calling handler (see native()), then turns the result into a value, an
# error or a warning.
run_verb <- function(res, call) {
  res <- withCallingHandlers(res, error = function(e) native_error(e, call))
  verb_result(res, call)
}

# list(value, error, limited) from a verb's .Call: the value, the error it
# describes, or the value with a warning for elements that hit a limit.
verb_result <- function(res, call) {
  if (!is.null(res$error)) {
    raise_match_error(res$error, call)
  }
  if (res$limited > 0) {
    n <- res$limited
    warning(structure(
      class = c("zuregex_warning_limit", "warning", "condition"),
      list(
        message = sprintf(
          "%s element%s of `x` hit a match limit and %s `NA`.",
          format(n, scientific = FALSE),
          if (n == 1) "" else "s",
          if (n == 1) "is" else "are"
        ),
        call = call,
        count = n
      )
    ))
  }
  res$value
}

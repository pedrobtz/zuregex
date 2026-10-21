# Conditions. Every error the package raises inherits from `zuregex_error`,
# with a subclass naming its kind, so callers and tests match on classes,
# never on message text (design section 8).

zuregex_abort <- function(kind, message, ..., call = NULL) {
  cond <- structure(
    class = c(
      paste0("zuregex_error_", kind),
      "zuregex_error",
      "error",
      "condition"
    ),
    list(message = message, call = call, ...)
  )
  stop(cond)
}

# The user-facing function that called an internal helper, for the `call`
# field of a condition.
user_call <- function(n = 2L) {
  sys.call(-n)
}

check_string <- function(x, arg, call) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    zuregex_abort(
      "argument",
      sprintf("`%s` must be a single string, not %s.", arg, describe(x)),
      call = call
    )
  }
}

check_flag <- function(x, arg, call) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    zuregex_abort(
      "argument",
      sprintf("`%s` must be `TRUE` or `FALSE`, not %s.", arg, describe(x)),
      call = call
    )
  }
}

check_choice <- function(x, choices, arg, call) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !x %in% choices) {
    zuregex_abort(
      "argument",
      sprintf(
        "`%s` must be one of %s, not %s.",
        arg,
        paste0("\"", choices, "\"", collapse = " or "),
        describe(x)
      ),
      call = call
    )
  }
}

describe <- function(x) {
  if (is.null(x)) {
    return("`NULL`")
  }
  if (length(x) == 1L && is.atomic(x)) {
    if (is.na(x)) {
      return("`NA`")
    }
    if (is.character(x)) {
      return(sprintf("the string \"%s\"", x))
    }
    return(sprintf("`%s`", format(x)))
  }
  sprintf("a %s vector of length %d", typeof(x), length(x))
}

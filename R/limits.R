#' Bound the work a match may do
#'
#' PCRE2 matches by backtracking, so a pattern such as `(a+)+b` can take
#' time exponential in the length of the subject. zuregex makes no
#' linear-time promise; for that, use the re2 package. What it promises is
#' that limits bound the work per element, and that hitting one is either a
#' classed error or an `NA` you asked for.
#'
#' Pass `re_limits()` as `limits =` to any matching function, or set it for
#' the session with `options(zuregex.limits = re_limits(...))`. The argument
#' wins over the option. `NULL` keeps PCRE2's default for that limit.
#'
#' @param match The most times PCRE2's internal match function may be
#'   called for one search; PCRE2's default is 10,000,000. The JIT
#'   compiler honours it too.
#' @param depth The deepest backtracking nesting for one search; PCRE2's
#'   default equals `match`. The JIT compiler ignores it.
#' @param heap The most heap memory, in kibibytes, the interpreter may use
#'   for backtracking in one search; PCRE2's default is 20,000,000. The JIT
#'   compiler ignores it.
#' @param on_limit What an element that hits a limit gives: `"error"`
#'   raises a `zuregex_error_limit` naming the limit and the element;
#'   `"na"` gives `NA` for that element and one warning of class
#'   `zuregex_warning_limit` for the call, counting how many did.
#' @return An object of class `re_limits`.
#' @export
#' @examples
#' x <- strrep("a", 30)
#' try(re_detect(x, "(a+)+b", limits = re_limits(match = 1000)))
#' re_detect(c(x, "ab"), "(a+)+b", limits = re_limits(match = 1000, on_limit = "na"))
#'
#' old <- options(zuregex.limits = re_limits(match = 1e5))
#' options(old)
re_limits <- function(
  match = NULL,
  depth = NULL,
  heap = NULL,
  on_limit = c("error", "na")
) {
  call <- sys.call()
  if (missing(on_limit)) {
    on_limit <- "error"
  }
  check_choice(on_limit, c("error", "na"), "on_limit", call)
  check_limit_values(list(match = match, depth = depth, heap = heap), call)
  structure(
    list(match = match, depth = depth, heap = heap, on_limit = on_limit),
    class = "re_limits"
  )
}

#' @export
format.re_limits <- function(x, ...) {
  show <- function(v) {
    if (is.null(v)) "default" else format(v, big.mark = ",", scientific = FALSE)
  }
  heap <- if (is.null(x$heap)) "default" else paste(show(x$heap), "KiB")
  sprintf(
    "<re_limits> match: %s, depth: %s, heap: %s, on_limit: \"%s\"",
    show(x$match),
    show(x$depth),
    heap,
    x$on_limit
  )
}

#' @export
print.re_limits <- function(x, ...) {
  cat(format(x), "\n", sep = "")
  invisible(x)
}

check_limit_values <- function(values, call) {
  for (name in names(values)) {
    v <- values[[name]]
    if (
      !is.null(v) &&
        (!is.numeric(v) ||
          length(v) != 1L ||
          is.na(v) ||
          v < 1 ||
          v > 4294967295 ||
          v != trunc(v))
    ) {
      zuregex_abort(
        "argument",
        sprintf(
          "`%s` must be `NULL` or a whole number from 1 to 4294967295, not %s.",
          name,
          describe(v)
        ),
        call = call
      )
    }
  }
}

# The limits a call uses, as the double vector the C verbs read: match,
# depth and heap (NA for PCRE2's default), then 1 for on_limit = "na".
# PCRE2's defaults and on_limit = "error", as call_limits() passes them.
no_limits <- c(NA_real_, NA_real_, NA_real_, 0)

# The limits a verb passes to C: no_limits, without reading them, unless
# the call or the option sets some.
verb_limits <- function(limits, call) {
  if (is.null(limits) && is.null(getOption("zuregex.limits"))) {
    no_limits
  } else {
    call_limits(limits, call)
  }
}

call_limits <- function(limits, call) {
  if (is.null(limits)) {
    limits <- getOption("zuregex.limits")
  }
  if (is.null(limits)) {
    return(no_limits)
  }
  if (!inherits(limits, "re_limits")) {
    zuregex_abort(
      "argument",
      sprintf(
        "`limits` and the `zuregex.limits` option must be `NULL` or made by `re_limits()`, not %s.",
        describe(limits)
      ),
      call = call
    )
  }
  # An object edited after re_limits() made it is checked again: C reads
  # these values as unsigned integers.
  check_limit_values(limits[c("match", "depth", "heap")], call)
  if (!is_string(limits$on_limit) || !limits$on_limit %in% c("error", "na")) {
    zuregex_abort(
      "argument",
      "`limits$on_limit` must be \"error\" or \"na\".",
      call = call
    )
  }
  num <- function(v) if (is.null(v)) NA_real_ else as.double(v)
  c(
    num(limits$match),
    num(limits$depth),
    num(limits$heap),
    as.double(limits$on_limit == "na")
  )
}

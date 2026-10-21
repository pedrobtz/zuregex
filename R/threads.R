#' Thread cap for matching
#'
#' Matching runs on several threads with OpenMP when a call's subjects add
#' up to more than an internal size threshold, and on one thread below it.
#' `re_threads()` reports the most threads a call may use;
#' `re_threads(n)` caps it for the rest of the session. The cap applies only
#' to zuregex's own matching, not to other OpenMP code in the process.
#'
#' Results never depend on the number of threads, so this is a performance
#' control, not a reproducibility one. In a build without OpenMP the value is
#' always 1 and a cap has no effect; [zuregex_info()] reports which build
#' this is.
#'
#' @param n `NULL` to query the effective maximum, a whole number of at
#'   least 1 to cap the threads, or `0` to remove the cap. Values above the
#'   machine's thread count are allowed and are the same as no cap.
#' @return Querying returns the effective maximum as an integer. Setting
#'   returns the previous cap invisibly, `0` meaning none was set, so
#'   `old <- re_threads(1); re_threads(old)` restores it exactly.
#' @export
#' @examples
#' re_threads()
#' old <- re_threads(1)
#' re_threads(old)
re_threads <- function(n = NULL) {
  if (is.null(n)) {
    return(.Call(zuregex_threads_c, NULL))
  }
  if (
    !is.numeric(n) ||
      length(n) != 1L ||
      is.na(n) ||
      n < 0 ||
      n != trunc(n) ||
      n > .Machine$integer.max
  ) {
    zuregex_abort(
      "argument",
      sprintf(
        "`n` must be `NULL` or a whole number of 0 or more, not %s.",
        describe(n)
      ),
      call = sys.call()
    )
  }
  invisible(.Call(zuregex_threads_c, as.integer(n)))
}

# The serial threshold in total subject bytes; NULL queries, a number sets
# it and returns the previous value. Internal: for tests and measurement.
serial_bytes <- function(n = NULL) {
  .Call(zuregex_serial_bytes_c, if (is.null(n)) NULL else as.double(n))
}

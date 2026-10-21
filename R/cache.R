#' The compiled-pattern cache
#'
#' Every `re_*()` function compiles a character `pattern` through a cache of
#' recently used compiled patterns, so a pattern used again, in a loop or
#' across calls, is not recompiled. Patterns are keyed by their text,
#' `flags`, `dialect`, `literal` and `jit`. The least recently used pattern
#' is dropped when the cache is full. Patterns longer than 65,536 characters
#' are never cached.
#'
#' `re` objects from [re_compile()] stay valid when the cache drops their
#' pattern or is cleared.
#'
#' @param n `NULL` to query the capacity, or a whole number from 0 to 256 to
#'   set it. 0 turns the cache off. Shrinking the cache drops the least
#'   recently used patterns.
#' @return `re_cache_size()` returns the capacity; when setting it, the
#'   previous capacity, invisibly. `re_cache_clear()` returns the number of
#'   patterns it dropped, invisibly.
#' @export
#' @examples
#' re_cache_size()
#' old <- re_cache_size(16)
#' re_cache_size(old)
#' re_cache_clear()
re_cache_size <- function(n = NULL) {
  if (is.null(n)) {
    return(.Call(zuregex_cache_size_c, NULL))
  }
  if (
    !is.numeric(n) ||
      length(n) != 1L ||
      is.na(n) ||
      n != trunc(n) ||
      n < 0 ||
      n > 256
  ) {
    zuregex_abort(
      "argument",
      sprintf(
        "`n` must be `NULL` or a whole number from 0 to 256, not %s.",
        describe(n)
      ),
      call = sys.call()
    )
  }
  invisible(.Call(zuregex_cache_size_c, as.integer(n)))
}

#' @rdname re_cache_size
#' @export
re_cache_clear <- function() {
  invisible(.Call(zuregex_cache_clear_c))
}

# Counters for tests: size, capacity, hits, misses and evictions since the
# package was loaded.
cache_stats <- function() {
  .Call(zuregex_cache_stats_c)
}

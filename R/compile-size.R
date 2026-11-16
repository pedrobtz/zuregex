#' Cap the size of a compiled pattern
#'
#' A short pattern can compile to a very large program: counted repeats of
#' a group copy the group, so nested ones multiply. A 77-character pattern
#' with three nested `{253}` repeats compiles to 458 MB. zuregex refuses
#' any pattern whose compiled form would exceed the cap, with a
#' `zuregex_error_compile`, before PCRE2 allocates the memory.
#'
#' The default, 16 MiB, is about a hundred times the largest realistic
#' pattern: an alternation of keywords at the cache's 65,536-character
#' limit compiles to about 150 KB. The cap bounds compiling only; to bound
#' matching, use [re_limits()].
#'
#' The cap applies to every compile in the session, including compiles
#' through the C API. A pattern already in the cache keeps working when the
#' cap is lowered; [re_cache_clear()] drops it.
#'
#' @param bytes `NULL` to query the cap, or a whole number of bytes, at
#'   least 1, to set it. `Inf` turns the cap off.
#' @return The cap in bytes. When setting it, the previous cap, invisibly.
#' @export
#' @examples
#' re_compile_size()
#' try(re_compile("(?:(?:(?:ab|cd){200}){200}){200}"))
#' old <- re_compile_size(2^30)
#' re_compile_size(old)
re_compile_size <- function(bytes = NULL) {
  if (is.null(bytes)) {
    return(.Call(zuregex_compile_size_c, NULL))
  }
  if (
    !is.numeric(bytes) ||
      length(bytes) != 1L ||
      is.na(bytes) ||
      bytes < 1 ||
      (is.finite(bytes) && bytes != trunc(bytes))
  ) {
    zuregex_abort(
      "argument",
      sprintf(
        "`bytes` must be `NULL`, `Inf` or a whole number of at least 1, not %s.",
        describe(bytes)
      ),
      call = sys.call()
    )
  }
  invisible(.Call(zuregex_compile_size_c, as.double(bytes)))
}

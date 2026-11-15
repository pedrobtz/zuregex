#' @section Scope:
#' zuregex matches with PCRE2's 8-bit library and its just-in-time
#' compiler. It leaves out, by design:
#'
#' * A linear-time guarantee. PCRE2 backtracks; [re_limits()] bounds the
#'   work of a match, and the re2 package matches in linear time.
#' * Pattern syntax of its own. Patterns are PCRE2's, as with base R's
#'   `perl = TRUE`.
#' * PCRE2's 16-bit and 32-bit libraries, and its `pcre2grep` and
#'   `pcre2test` programs.
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @useDynLib zuregex, .registration = TRUE
## usethis namespace: end
NULL

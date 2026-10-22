#' Describe the bundled PCRE2 library
#'
#' Reports the version of PCRE2 that zuregex was built with, whether its
#' just-in-time (JIT) compiler works on this machine, and how matching is
#' set up: OpenMP, the threads and cores it can use, the input size it
#' starts at, and the cache size.
#'
#' The JIT compiler can be built in and still fail at run time, on a CPU it
#' does not support or where the system refuses executable memory. PCRE2
#' then matches with its interpreter, which gives the same results more
#' slowly. `jit_usable` tells the two cases apart by JIT-compiling a small
#' pattern.
#'
#' @return A list with elements:
#'   * `pcre2_version`: the bundled PCRE2 version, such as `"10.48"`.
#'   * `pcre2_date`: its release date.
#'   * `unicode`: whether Unicode and UTF-8 support is built in.
#'   * `unicode_version`: the Unicode version of PCRE2's character tables.
#'   * `jit`: whether the JIT compiler is built in.
#'   * `jit_usable`: whether the JIT compiler works on this machine.
#'   * `jit_target`: the architecture the JIT compiler generates code for,
#'     or `NA` without it.
#'   * `openmp`: whether this build matches on several threads. On macOS
#'     that needs the OpenMP headers from
#'     <https://mac.r-project.org/openmp/> when zuregex is built.
#'   * `threads`: the most threads a call may use; see [re_threads()].
#'   * `cores`: the processors OpenMP sees, or `NA` without OpenMP.
#'   * `serial_bytes`: the total size of a call's subjects, in bytes, below
#'     which it runs on one thread, because starting threads would cost
#'     more than they save.
#'   * `cache_size`: the pattern cache's capacity; see [re_cache_size()].
#' @export
#' @examples
#' zuregex_info()
zuregex_info <- function() {
  info <- .Call(zuregex_info_c)
  version <- strsplit(info$pcre2_version, " ", fixed = TRUE)[[1]]
  list(
    pcre2_version = version[[1]],
    pcre2_date = version[[2]],
    unicode = info$unicode,
    unicode_version = info$unicode_version,
    jit = info$jit,
    jit_usable = info$jit_usable,
    jit_target = info$jit_target,
    openmp = .Call(zuregex_openmp_c),
    threads = re_threads(),
    cores = .Call(zuregex_cores_c),
    serial_bytes = serial_bytes(),
    cache_size = re_cache_size()
  )
}

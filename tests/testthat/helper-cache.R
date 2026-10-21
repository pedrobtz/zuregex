# Runs `code` with an empty cache of the given capacity, restoring the
# previous capacity afterwards and leaving the cache empty.
local_cache <- function(capacity = 128L, env = parent.frame()) {
  old <- re_cache_size(capacity)
  re_cache_clear()
  withr::defer(
    {
      re_cache_clear()
      re_cache_size(old)
    },
    envir = env
  )
  invisible(old)
}

stats_delta <- function(before, after = zuregex:::cache_stats()) {
  vapply(
    c("hits", "misses", "evictions"),
    function(k) after[[k]] - before[[k]],
    numeric(1)
  )
}

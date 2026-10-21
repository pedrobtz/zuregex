# Base R's results in zuregex's conventions, for parity tests.

# regexpr() as a start/end matrix: NA for no match, end = start - 1 for an
# empty match.
base_locate <- function(x, pattern) {
  m <- regexpr(pattern, x, perl = TRUE)
  start <- as.integer(m)
  len <- attr(m, "match.length")
  start[start == -1L] <- NA_integer_
  end <- start + len - 1L
  cbind(start = start, end = end)
}

# gregexpr() as re_locate_all()'s data frame, for subjects with no NA.
base_locate_all <- function(x, pattern) {
  m <- gregexpr(pattern, x, perl = TRUE)
  rows <- lapply(seq_along(m), function(i) {
    start <- as.integer(m[[i]])
    if (identical(start, -1L)) {
      return(NULL)
    }
    len <- attr(m[[i]], "match.length")
    data.frame(
      element = i,
      match = seq_along(start),
      start = start,
      end = start + len - 1L
    )
  })
  out <- do.call(
    rbind,
    c(
      list(data.frame(
        element = integer(),
        match = integer(),
        start = integer(),
        end = integer()
      )),
      rows
    )
  )
  rownames(out) <- NULL
  out
}

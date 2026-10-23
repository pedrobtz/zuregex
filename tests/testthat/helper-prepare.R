# Every verb's result on x and p, for comparing the fast path, a pattern
# per element and an re object. The verbs that always go through
# prepare() are included: a named group, a replacement function and split.
# `...` goes to every verb, for flags and literal.
every_path_result <- function(x, p, ...) {
  list(
    re_detect(x, p, ...),
    re_count(x, p, ...),
    re_locate(x, p, ...),
    re_locate_all(x, p, ...),
    re_extract(x, p, ..., group = "w"),
    re_extract(x, p, ..., group = 1),
    re_extract_all(x, p, ...),
    re_match(x, p, ...),
    re_match_all(x, p, ...),
    re_replace(x, p, ..., "<${w}>"),
    re_replace(x, p, ..., function(m) toupper(m[["0"]])),
    re_expand(x, p, ..., "[$1]"),
    re_split(x, p, ..., keep_groups = TRUE)
  )
}

# The three ways to pass one pattern for every element of x.
every_path <- function(x, pattern) {
  list(
    fast = pattern,
    vector = rep(pattern, length(x)),
    re = re_compile(pattern)
  )
}

# A subject on which "^(a+)+$" backtracks exponentially: no match, and no
# required character PCRE2 could check for first.
pathological <- function() {
  list(x = paste0(strrep("a", 28), "!"), pattern = "^(a+)+$")
}

# Every matching verb, called on x and pattern with ... passed through.
every_verb <- function() {
  list(
    re_detect = function(x, p, ...) re_detect(x, p, ...),
    re_count = function(x, p, ...) re_count(x, p, ...),
    re_locate = function(x, p, ...) re_locate(x, p, ...),
    re_locate_all = function(x, p, ...) re_locate_all(x, p, ...),
    re_extract = function(x, p, ...) re_extract(x, p, ...),
    re_extract_all = function(x, p, ...) re_extract_all(x, p, ...),
    re_match = function(x, p, ...) re_match(x, p, ...),
    re_match_all = function(x, p, ...) re_match_all(x, p, ...),
    re_replace = function(x, p, ...) re_replace(x, p, "#", ...),
    re_replace_fun = function(x, p, ...) {
      re_replace(x, p, function(m) rep("#", nrow(m)), ...)
    },
    re_expand = function(x, p, ...) re_expand(x, p, "$0", ...),
    re_split = function(x, p, ...) re_split(x, p, ...)
  )
}

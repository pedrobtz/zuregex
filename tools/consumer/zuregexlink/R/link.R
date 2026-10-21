link_match <- function(pattern, x) .Call(link_match_c, pattern, enc2utf8(x))
link_replace <- function(pattern, x, template) {
  .Call(link_replace_c, pattern, x, template)
}
link_groups <- function(pattern) .Call(link_groups_c, pattern)
link_version <- function() .Call(link_version_c)

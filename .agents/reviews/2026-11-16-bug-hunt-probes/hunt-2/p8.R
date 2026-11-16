.libPaths(c("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz-zuregex/e53874e6-da4a-401d-a173-3b05192b4f61/scratchpad/hunt/lib", .libPaths()))
library(zuregex)
M <- function(e) tryCatch(e, error = function(e) if (inherits(e, "zuregex_error_limit")) paste0("limit:", e$limit) else class(e)[1])
set.seed(2)
words <- function(n) paste(replicate(n, paste(sample(letters, sample(2:8, 1)), collapse = "")), collapse = " ")
cases <- list(
  list('"(?:[^"\\\\]|\\\\.)*"', function(n) paste0('say "', strrep("ab\\\"", n %/% 4), '" ok')),
  list("(.|\\n)*", function(n) substr(words(n), 1, n)),
  list("(\\s|\\S)*end", function(n) paste0(substr(words(n), 1, n), "end")),
  list("^(\\w+\\s?)*$", function(n) substr(words(n), 1, n)),
  list("<p>(.|\\n)*?</p>", function(n) paste0("<p>", substr(words(n), 1, n), "</p>")),
  list("(?:[^,]*,)*[^,]*", function(n) strrep("ab,", n %/% 3)),
  list("^(?:\\d+|[a-z]+|\\s)*$", function(n) substr(words(n), 1, n)),
  list("(\\d{3}-)+\\d{3}", function(n) strrep("123-", n %/% 4))
)
for (cs in cases) for (n in c(1000, 4000, 16000, 64000)) {
  s <- cs[[2]](n); q <- cs[[1]]
  g <- tryCatch(grepl(q, s, perl = TRUE), warning = function(w) "warn")
  gl <- tryCatch(regexpr(q, s, perl = TRUE), warning = function(w) "warn"); gl <- if (is.character(gl)) gl else paste(gl, attr(gl, "match.length"))
  z <- M(re_detect(s, q)); zl <- M(re_locate(s, q)); zl <- if (is.character(zl)) zl else paste(zl[1], zl[2] - zl[1] + 1)
  zr <- M(re_replace(s, q, "X")); zr <- if (startsWith(zr, "limit")) zr else "ok"
  cat(sprintf("%-26s n=%-6d grepl=%-5s regexpr=%-12s | re_detect=%-16s re_locate=%-16s re_replace=%s\n", q, nchar(s), g, gl, z, zl, zr))
}

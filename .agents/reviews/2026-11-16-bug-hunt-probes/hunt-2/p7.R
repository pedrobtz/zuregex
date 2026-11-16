.libPaths(c("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz-zuregex/e53874e6-da4a-401d-a173-3b05192b4f61/scratchpad/hunt/lib", .libPaths()))
library(zuregex)
M <- function(e) tryCatch(e, error = function(e) paste(class(e)[1], gsub("\n", " | ", conditionMessage(e))))
set.seed(1); txt <- paste(sample(c(letters, " ", "\n"), 8000, TRUE), collapse = "")
print(M(re_detect(txt, "^(?:.|\\n)*$")))
print(M(re_detect(txt, "^(?:.|\\n)*$", limits = re_limits(match = 2^32 - 1, depth = 2^32 - 1, heap = 2^32 - 1))))
print(M(re_detect(txt, "^(?:.|\\n)*$", limits = re_limits(on_limit = "na"))))
print(grepl("^(?:.|\\n)*$", txt, perl = TRUE))
# smallest failing size
for (q in c("^(?:.|\\n)*$", "(a|b)*", "(?:a|b)*c", "(\\w+\\s?)*", "^(\\w+,)*\\w+$")) {
  f <- function(n) { s <- if (grepl("w", q)) strrep("ab,", n %/% 3) else strrep("ab", n %/% 2); is.logical(M(re_detect(s, q))) }
  lo <- 1; hi <- 4e6; if (f(hi)) { cat(q, ": ok up to 4 MB\n"); next }
  while (lo < hi) { mid <- (lo + hi) %/% 2; if (f(mid)) lo <- mid + 1 else hi <- mid }
  s <- if (grepl("w", q)) strrep("ab,", lo %/% 3) else strrep("ab", lo %/% 2)
  cat(sprintf("%-16s first fails at %d bytes; grepl(perl=TRUE) there: %s; interpreter: %s\n", q, lo, tryCatch(grepl(q, s, perl = TRUE), warning = function(w) "warn"), M(re_detect(s, re_compile(q, jit = FALSE)))))
}

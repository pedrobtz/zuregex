# JIT vs interpreter (and base R) on variable-length lookbehinds.
.libPaths(c("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz-zuregex/e53874e6-da4a-401d-a173-3b05192b4f61/scratchpad/hunt/lib", .libPaths()))
library(zuregex)
set.seed(as.integer(commandArgs(TRUE)[1]))
IN <- c("a", "b", "ab", "a?", "b{1,2}", "a{0,2}", "(?>ab|a)", "(?>a|ab)", "a++", "a?+", "b*+"[0], "[ab]", "é", "é?", "\\R", "\\X", ".", "(?:a|bc)", "(a)", "\\b", "^", "(?i)A", "😀", "a{2}", "(?=b)", "(?!a)", "\\d", "(?:ab)?", "a{1,3}+", "(?>a{1,2})", "(?>b?)", "\\N{1,2}", "\\w{1,2}+")
OUT <- c("", "a", "b", ".", "\\w", "$", "é", "\\n", "(?=a)", "b?", "(a|b)")
SUB <- c("a", "b", "a", "b", "é", "😀", "\n", "\r\n", "1", " ")
nb <- 0; nt <- 0; seen <- character()
for (it in 1:8000) {
  body <- paste(sample(IN, sample(1:3, 1), TRUE), collapse = ""); if (runif(1) < .4) body <- paste0(body, "|", paste(sample(IN, sample(1:2, 1), TRUE), collapse = ""))
  p <- paste0(sample(OUT, 1), sample(c("(?<=", "(?<!"), 1), body, ")", sample(OUT, 1))
  x <- paste(sample(SUB, sample(0:7, 1), TRUE), collapse = "")
  j <- tryCatch(re_locate_all(x, p), error = function(e) NULL); if (is.null(j)) next
  i <- re_locate_all(x, re_compile(p, jit = FALSE)); nt <- nt + 1
  mj <- re_match_all(x, p); mi <- re_match_all(x, re_compile(p, jit = FALSE))
  if (!identical(i, j) || !identical(mi, mj)) { nb <- nb + 1; key <- gsub("[^\\\\A-Za-z>+?{]", "", body); atom <- regmatches(body, regexpr("\\\\R|\\(\\?>|\\+\\+|\\?\\+|\\}\\+|\\\\X", body)); k <- if (length(atom)) atom else "other"; if (sum(seen == k) < 4) cat("JIT!=INTERP [", k, "] p:", p, " x:", encodeString(x), " jit:", paste(j$start, j$end, sep = "-", collapse = " "), " interp:", paste(i$start, i$end, sep = "-", collapse = " "), "\n"); seen <- c(seen, k) }
}
cat("compared", nt, "jit!=interp", nb, "\n"); print(table(seen))

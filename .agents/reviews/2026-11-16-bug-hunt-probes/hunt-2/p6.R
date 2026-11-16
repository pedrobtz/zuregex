.libPaths(c("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz-zuregex/e53874e6-da4a-401d-a173-3b05192b4f61/scratchpad/hunt/lib", .libPaths()))
library(zuregex)
T <- function(e) { r <- tryCatch(suppressWarnings(e), error = function(e) paste("ERR:", class(e)[1], gsub("\n", " | ", conditionMessage(e)))); cat(deparse(substitute(e), width.cutoff = 200)[1], "\n   ->", paste(deparse(r), collapse = " "), "\n") }
x <- paste0(strrep("a", 12), "!"); p <- "^(a+)+$"
L <- re_limits(match = 100, on_limit = "na")
xs <- c("aaa", x, "b", x, NA)
T(re_detect(xs, p, limits = L)); T(re_detect(xs, p, negate = TRUE, limits = L)); T(re_count(xs, p, limits = L)); T(re_locate(xs, p, limits = L)); T(re_extract(xs, p, limits = L)); T(re_replace(xs, p, "z", limits = L)); T(re_split(xs, p, limits = L)); T(re_match(xs, p, limits = L)); T(re_locate_all(xs, p, limits = L)); T(re_extract_all(xs, p, limits = L)); T(re_match_all(xs, p, limits = L)); T(re_expand(xs, p, "z", limits = L)); T(re_replace(xs, p, function(m) rep("F", nrow(m)), limits = L))
y <- paste0("aaa ", strrep("a", 12), "!"); p2 <- "\\b(a+)+\\b(?!!)"; ys <- c("aa", y, "a a")
T(re_locate_all(ys, p2, limits = L)); T(re_count(ys, p2, limits = L)); T(re_extract_all(ys, p2, limits = L)); T(re_replace(ys, p2, "z", limits = L)); T(re_split(ys, p2, limits = L)); T(re_match_all(ys, p2, limits = L)); T(re_replace(ys, p2, function(m) {print(m); paste0("F", seq_len(nrow(m)))}, limits = L))
ri <- re_compile(p, jit = FALSE)
T(re_detect(x, ri, limits = re_limits(depth = 5))); T(re_detect(x, ri, limits = re_limits(heap = 1))); T(re_detect(x, ri, limits = re_limits(depth = 5, on_limit = "na")))
big <- paste0(strrep("a", 5000), "!")
T(re_detect(big, re_compile("(a|b)*c", jit = FALSE), limits = re_limits(heap = 1))); T(re_detect(big, re_compile("(a|b)*c", jit = FALSE), limits = re_limits(depth = 100)))
# defaults on ordinary few-KB inputs vs grepl
set.seed(1); txt <- paste(sample(c(letters, " ", "\n", "é"), 8000, TRUE), collapse = "")
pats <- c("(\\w+\\s?)+$", "^(.*\\n)*.*z.*$", "(?s)(a.*?b)+", "(\\w|é)+", "((a|b|c)+\\s)*", "(?:(?:[a-z]+)\\s*)*\\n", "^(?:.|\\n)*$", "(.|\\n)*?zz")
for (q in pats) { g <- tryCatch(grepl(q, txt, perl = TRUE), warning = function(w) paste("W", conditionMessage(w)), error = function(e) "E"); z <- tryCatch(re_detect(txt, q), error = function(e) paste("ERR", class(e)[1])); zi <- tryCatch(re_detect(txt, re_compile(q, jit = FALSE)), error = function(e) paste("ERR", class(e)[1])); zc <- tryCatch(re_count(txt, q), error = function(e) paste("ERR", class(e)[1])); gc <- lengths(regmatches(txt, gregexpr(q, txt, perl = TRUE))); cat(sprintf("%-28s grepl=%s zu=%s zu_interp=%s count=%s gregexpr=%s\n", q, g, z, zi, zc, gc)) }
big2 <- strrep("ab ", 30000)
for (q in c("(\\w+\\s?)+$", "(a|b| )*", "(?:ab )*", "(ab )*x")) { g <- tryCatch(grepl(q, big2, perl = TRUE), warning = function(w) paste("W", conditionMessage(w)), error = function(e) "E"); z <- tryCatch(re_detect(big2, q), error = function(e) paste("ERR", class(e)[1])); zi <- tryCatch(re_detect(big2, re_compile(q, jit = FALSE)), error = function(e) paste("ERR", class(e)[1])); cat(sprintf("%-28s grepl=%s zu=%s zu_interp=%s\n", q, g, z, zi)) }

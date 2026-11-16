.libPaths(c("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz-zuregex/e53874e6-da4a-401d-a173-3b05192b4f61/scratchpad/hunt/lib", .libPaths()))
library(zuregex)
show <- function(x, p) { j <- re_locate_all(x, p); i <- re_locate_all(x, re_compile(p, jit = FALSE)); g <- tryCatch(gregexpr(p, x, perl = TRUE)[[1]], error = function(e) NA, warning = function(w) NA)
  options(warn = -1); pcre_nojit <- { old <- options(PCRE_use_JIT = FALSE); r <- tryCatch(gregexpr(p, x, perl = TRUE)[[1]], error = function(e) NA); options(old); r }
  f <- function(g) if (length(g) == 1 && is.na(g)) "ERR" else if (g[1] == -1) "" else paste(g, g + attr(g, "match.length") - 1, sep = "-", collapse = " ")
  cat(sprintf("%-28s x=%-8s zu jit: %-12s zu interp: %-12s base R (JIT): %-12s base R (no JIT): %s\n", p, encodeString(x), paste(j$start, j$end, sep = "-", collapse = " "), paste(i$start, i$end, sep = "-", collapse = " "), f(g), f(pcre_nojit))) }
show("ab", "(?<=a(?=b)c?)b"); show("ab", "(?<=a(?=b))b"); show("ab", "(?<=a(?=b)|xx)b"); show("ab", "(?<=a\\b|xx)b"); show("a b", "(?<=a\\b|xx) "); show("ab", "(?<=a\\B|xx)b"); show("a\nb", "(?m)(?<=a$|xx)\\n"); show("ab", "(?<=a(?!c)|xx)b"); show("ab", "(?<=a(?!b)|xx)b")
show("aa", "(?<=a?+)"); show("ab", "(?<=\\w{1,2}+)\\w"); show("aab", "(?<=(?>a|ab))b"); show("ab", "(?<=a$|xx)b"); show("ab", "(?<=a\\z|xx)b"); show("ab", "(?<=a\\Z|xx)b"); show("ab", "(?<!a\\z|xx)b"); show("ab", "(?<=a(*ACCEPT)|xx)b"); show("abc", "(?<=ab?)c"); show("abc", "(?<=a.*)c"[0])
cat(re_detect("ab", "(?<=a(?=b)|xx)b"), re_detect("ab", re_compile("(?<=a(?=b)|xx)b", jit = FALSE)), grepl("(?<=a(?=b)|xx)b", "ab", perl = TRUE), "\n")
cat(re_replace("price: 10 USD", "(?<=\\d\\b|x{2}) USD", "$"), "|", re_replace("price: 10 USD", re_compile("(?<=\\d\\b|x{2}) USD", jit = FALSE), "$"), "|", sub("(?<=\\d\\b|x{2}) USD", "$", "price: 10 USD", perl = TRUE), "\n")

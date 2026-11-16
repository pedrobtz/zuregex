.libPaths(c("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz-zuregex/e53874e6-da4a-401d-a173-3b05192b4f61/scratchpad/hunt/lib", .libPaths()))
library(zuregex)
p <- "a(?<=a(?=b)c?)b"; x <- "ab"
cat("anchor none/start/full:", re_detect(x, p), re_detect(x, p, anchor = "start"), re_detect(x, p, anchor = "full"), "\n")
cat("jit=FALSE none/start/full:", re_detect(x, re_compile(p, jit = FALSE)), re_detect(x, re_compile(p, jit = FALSE), anchor = "start"), re_detect(x, re_compile(p, jit = FALSE), anchor = "full"), "\n")
cat("grepl:", grepl(p, x, perl = TRUE), " stringi (ICU):", stringi::stri_detect_regex(x, p), "\n")
p2 <- "(?<=\\R)\\n"; x2 <- "\r\n"
cat("\\R: jit", re_detect(x2, p2), "interp", re_detect(x2, re_compile(p2, jit = FALSE)), "grepl", grepl(p2, x2, perl = TRUE), "\n")
# mixed engines within one iteration: empty match then anchored retry runs the interpreter
p3 <- "|(?<=a(?=b)c?)b"; cat("locate_all jit:   ", paste(re_locate_all("ab", p3)$start, re_locate_all("ab", p3)$end, sep = "-"), "\n"); i <- re_locate_all("ab", re_compile(p3, jit = FALSE)); cat("locate_all interp:", paste(i$start, i$end, sep = "-"), "\n")
p4 <- "(?<=a(?=b)c?)b|"; j <- re_locate_all("ab", p4); i <- re_locate_all("ab", re_compile(p4, jit = FALSE)); cat("p4 jit:", paste(j$start, j$end, sep = "-"), " interp:", paste(i$start, i$end, sep = "-"), "\n")
cat("zuregex_info jit:", zuregex_info()$jit, zuregex_info()$jit_usable, "\n")

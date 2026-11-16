.libPaths(c("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz-zuregex/e53874e6-da4a-401d-a173-3b05192b4f61/scratchpad/hunt/lib", .libPaths()))
library(zuregex)
show <- function(x, p) { j <- re_locate_all(x, p); i <- re_locate_all(x, re_compile(p, jit = FALSE)); g <- gregexpr(p, x, perl = TRUE)[[1]]
  cat(sprintf("%-22s x=%-12s jit: %-22s interp: %-22s base R: %s\n", p, encodeString(x), paste(j$start, j$end, sep = "-", collapse = " "), paste(i$start, i$end, sep = "-", collapse = " "), paste(g, g + attr(g, "match.length") - 1, sep = "-", collapse = " "))) }
show("\r\nb", "(?<=\\R)"); show("\r\nb", "(?<=\\R)b"); show("\r\nb", "(?<=\\R)\\n"); show("a\r\nb", "(?<=\\R)."); show("a\r\nb", "(?<=\\R)"); show("a\r\nb", "(?<!\\R)\\n"); show("a\r\nb", "(?<!\\R)"); show("a\r\nb", "(?s)(?<=\\R)."); show("a\nb", "(?<=\\R)"); show("a\r\nb", "(?<=\\r\\n|\\n|\\r)"); show("a\r\nb", "(?<=(?>\\r\\n|\\n|\\r))"); show("a\r\nb", "(?<=a\\R)"); show("a\r\nb", "(?<=\\R)\\n?b")
cat("replace jit:   ", encodeString(re_replace("a\r\nb", "(?<=\\R)", "|")), "\n"); cat("replace interp:", encodeString(re_replace("a\r\nb", re_compile("(?<=\\R)", jit = FALSE), "|")), "\n"); cat("gsub:          ", encodeString(gsub("(?<=\\R)", "|", "a\r\nb", perl = TRUE)), "\n")
cat("detect jit / interp / grepl:", re_detect("\r\n", "(?<=\\R)\\n"), re_detect("\r\n", re_compile("(?<=\\R)\\n", jit = FALSE)), grepl("(?<=\\R)\\n", "\r\n", perl = TRUE), "\n")
cat("bytes jit/interp:", re_detect(charToRaw("\r\n"), "(?<=\\R)\\n"), re_detect(charToRaw("\r\n"), re_compile("(?<=\\R)\\n", jit = FALSE)), "\n")

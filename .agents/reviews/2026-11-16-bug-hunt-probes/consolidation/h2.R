.libPaths(Sys.getenv("WLIB")); suppressMessages(library(zuregex))
p <- "a(?<=a(?=b)c?)b"
cat("lookbehind: jit", re_detect("ab", p), " anchor=start", re_detect("ab", p, anchor = "start"), " jit=FALSE", re_detect("ab", re_compile(p, jit = FALSE)), " grepl", grepl(p, "ab", perl = TRUE), "\n")
cat("\\R lookbehind: jit", re_detect("\r\n", "(?<=\\R)\\n"), " jit=FALSE", re_detect("\r\n", re_compile("(?<=\\R)\\n", jit = FALSE)), " grepl", grepl("(?<=\\R)\\n", "\r\n", perl = TRUE), "\n")
m <- re_match("ab", "(?J)(?<n>a)(?<n>b)"); cat("dupnames re_match cols:", names(m), " values:", unlist(m), " group_names:", re_info(re_compile("(?J)(?<n>a)(?<n>b)"))$group_names[[1]], "\n")

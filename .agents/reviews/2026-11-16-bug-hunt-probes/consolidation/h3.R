.libPaths(Sys.getenv("WLIB")); suppressMessages(library(zuregex))
r <- re_compile("(?:a{50}){50}"); re_compile_size(100)
k <- function(e) tryCatch(force(e), error = function(c) class(c)[1])
cat("cap lowered: chr", k(re_detect("a", r)), " raw", k(re_detect(charToRaw("a"), r)), "\n")

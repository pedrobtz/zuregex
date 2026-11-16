.libPaths(Sys.getenv("WLIB")); suppressMessages(library(zuregex))
keep <- re_compile("again"); unloadNamespace("zuregex")
library.dynam.unload("zuregex", file.path(Sys.getenv("WLIB"), "zuregex")); rm(keep); gc(); cat("survived\n")

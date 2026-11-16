# A foreign external pointer inside an re object
.libPaths("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz-zuregex/e53874e6-da4a-401d-a173-3b05192b4f61/scratchpad/hunt/lib"); library(zuregex)
which <- commandArgs(TRUE)[1]
r <- re_compile("a")
foreign <- switch(which,
  env = { e <- new.env(); attr(e, "x") <- 1; e },   # not an extptr
  xptr_null = methods::new("externalptr"),           # NULL address extptr (not ours)
  xptr_live = { tc <- textConnection("abc"); attr(tc, "conn_id") },  # a live foreign extptr (connection id)
  xptr_dll = getNativeSymbolInfo("R_init_zuregex", "zuregex")$address) # extptr to code, class NativeSymbol
q <- unclass(r); q[[1]] <- foreign; attributes(q) <- attributes(r)
cat(which, "typeof:", typeof(q[[1]]), "\n")
cat("info:\n"); print(tryCatch(re_info(q)[c("pattern", "groups", "jit", "min_length")], error = function(e) conditionMessage(e)))
cat("detect:", tryCatch(re_detect(c("a", "b"), q), error = function(e) conditionMessage(e)), "\n")

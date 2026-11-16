.libPaths(c("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz-zuregex/e53874e6-da4a-401d-a173-3b05192b4f61/scratchpad/hunt/lib", .libPaths()))
library(zuregex)
pb <- "a\xff"; Encoding(pb) <- "UTF-8"
e <- tryCatch(re_detect("a", pb), error = function(e) e); print(class(e)); print(conditionCall(e)); 
e <- tryCatch(re_detect(c("a","b"), c(pb, "b")), error = function(e) e); print(class(e)); print(conditionMessage(e))
e <- tryCatch(re_compile(pb), error = function(e) e); print(class(e)); print(conditionMessage(e))
pbb <- "\xff"; Encoding(pbb) <- "bytes"
e <- tryCatch(re_detect("a", pbb), error = function(e) e); print(class(e)); print(conditionMessage(e)); print(conditionCall(e))
e <- tryCatch(re_compile(pbb), error = function(e) e); print(class(e)); print(conditionMessage(e))
e <- tryCatch(re_detect(c("a", "b"), c(pbb, "b")), error = function(e) e); print(class(e)); print(conditionMessage(e))
xb <- "a\xff"; Encoding(xb) <- "bytes"
print(tryCatch(re_detect(xb, pbb), error = function(e) conditionMessage(e)))
print(tryCatch(re_detect(xb, c(pbb)), error = function(e) conditionMessage(e)))
print(tryCatch(re_replace(xb, "a", pbb), error = function(e) conditionMessage(e)))
print(tryCatch(re_replace("abc", "b", pbb), error = function(e) conditionMessage(e)))

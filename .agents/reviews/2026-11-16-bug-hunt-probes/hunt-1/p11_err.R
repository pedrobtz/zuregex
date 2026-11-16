source("pre.R")
bad <- "\xff."
options(error = NULL)
r <- tryCatch(withCallingHandlers(re_compile(bad), error = function(e) {print(sys.calls()[-(1:4)])}), error = function(e) e)
print(class(r))
bp <- "\xe9"; Encoding(bp) <- "bytes"
r <- tryCatch(withCallingHandlers(re_detect("a", bp), error = function(e) {print(tail(sys.calls(), 6))}), error = function(e) e); print(class(r))
r <- tryCatch(re_detect(c("a","b"), c("a", bp)), error = function(e) e); print(class(r)); print(conditionMessage(r))
# compile error message for multi pattern via verb: which element number is reported?
r <- tryCatch(re_detect(c("a","b","c","d"), c("ok", "ok", "(bad", "(bad")), error = function(e) e); print(conditionMessage(r)); print(r$element)
r <- tryCatch(re_detect(c("a","b","c","d"), c(NA, "ok", "ok", "(bad")), error = function(e) e); print(conditionMessage(r)); print(r$element)
r <- tryCatch(re_detect(c("a","b","c"), re_compile(c(NA, "ok", "\\Cx"))), error = function(e) e); print(conditionMessage(r))
bx <- c("a","b","c"); Encoding(bx) <- "bytes"; bx[1] <- "\xff"; Encoding(bx) <- "bytes"
r <- tryCatch(re_detect(bx, re_compile(c(NA, "ok", "(*UTF)x"))), error = function(e) e); print(conditionMessage(r)); print(r$element)

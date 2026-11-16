# The fuzz input from #128: 77 characters whose nested counted repeats
# compile to 458 MB of bytecode, and 1.8 GB at peak, without a cap.
nested_repeats <- function() {
  "((sM||sM((sM||R??){253}]]+K\\b$wR)3]}2{5.]w+\\R??){253}]]w+K\\b$wR){253}].]w+\\Kb"
}

# Sets the compiled-size cap until the calling test ends.
local_compile_size <- function(bytes, env = parent.frame()) {
  old <- re_compile_size(bytes)
  withr::defer(re_compile_size(old), envir = env)
  invisible(old)
}

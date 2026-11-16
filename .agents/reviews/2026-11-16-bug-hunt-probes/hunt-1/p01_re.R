source("pre.R")
# info claims: prefix
for (p in c("abc\\Kd", "ab(?#[)|cd", "a(?#()|b", "a\\Q(\\E|b", "ab\\Q|\\Ec", "a{2}b", "ab{0}c", "a{,3}", "abc", "a\\.b", "ab?c", "a#b", "café+", "ab(?i)c", "a\\Eb|c","a\\<b", "a\\ b", "a]b", "a}b","a{b", "a{1,b", "a-b","a&b")) {
  r <- re_info(re_compile(p)); cat(sprintf("%-14s prefix=[%s] min=%d\n", p, r$prefix, r$min_length))
}
t(re_extract(c("abcd","cd","b"), "abc\\Kd"))
t(re_detect(c("cd","b","|"), c("ab(?#[)|cd","a\\Q(\\E|b","a\\Q(\\E|b")))
t(re_info(re_compile(c(a="(?<y>a)(b)", b=NA, c="x"), flags="mi")))
t(re_info(re_compile("a", flags="xx"))$flags)
for (f in c("a","aD","aSaW","aTaP","xx","x","imsxnUJur","uaD","Ji","r","ia","aaD")) { r<-tryCatch(re_info(re_compile("a", flags=f))$flags, error=function(e) paste("ERR", conditionMessage(e))); cat(f,"->",r,"\n"); if(!grepl("ERR",r)) { r2 <- tryCatch(re_info(re_compile("a", flags=r))$flags, error=function(e) paste("ERR", conditionMessage(e))); cat("   roundtrip ->", r2, "\n")}}
t(re_info(re_compile("a.b", literal=TRUE, flags="i")))
t(re_info(re_compile("a.b", literal=TRUE)))
t(re_info(re_compile("(?<n>a)|(?<n>b)", flags="J"))$group_names)
t(re_info(re_compile("éé(.)"))  )
t(re_info(re_compile(character())))
str(re_info(re_compile(c("a",NA))))
# jit cache key
re_cache_clear()
a <- re_compile("jitprobe", jit=FALSE); b <- re_compile("jitprobe", jit=TRUE)
t(c(re_info(a)$jit, re_info(b)$jit))
re_cache_clear()
b <- re_compile("jitprobe2", jit=TRUE); a <- re_compile("jitprobe2", jit=FALSE)
t(c(re_info(a)$jit, re_info(b)$jit))
t(re_detect("x", "jitprobe2")); t(re_info(a)$jit)
# dialect cache key
j <- re_compile("a$", dialect="js"); p <- re_compile("a$")
t(c(re_detect("a\n", j), re_detect("a\n", p), re_detect("a\n","a$")))
l <- re_compile("a.c", literal=TRUE); nl <- re_compile("a.c")
t(c(re_detect("abc", l), re_detect("abc", nl)))

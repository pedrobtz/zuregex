source("pre.R")
cat(Sys.getlocale(), "\n")
cps <- c(1:0x2100, 0x3000, 0xFEFF, 0x1F600, 0xE0001)
cps <- cps[!(cps >= 0xD800 & cps <= 0xDFFF)]
ch <- intToUtf8(cps, multiple = TRUE)
e <- re_escape(ch)
stopifnot(all(Encoding(e) %in% c("unknown","UTF-8")))
chk <- function(lab, ok) { bad <- which(!ok | is.na(ok)); cat(lab, ": bad =", length(bad), if (length(bad)) paste(sprintf("U+%04X", cps[head(bad, 30)]), collapse=" "), "\n") }
g <- function(expr) tryCatch(expr, error = function(e) {cat("ERR", conditionMessage(e), "\n"); rep(NA, length(ch))})
chk("plain full", g(re_detect(ch, e, anchor="full")))
chk("x full", g(re_detect(ch, e, anchor="full", flags="x")))
chk("xx full", g(re_detect(ch, e, anchor="full", flags="xx")))
chk("in context x", g(re_detect(paste0("a", ch, "b"), paste0("a", e, "b"), anchor="full", flags="x")))
chk("after-quant ctx", g(re_detect(paste0("a", ch, "b"), paste0("a?a", e, "b"), anchor="full")))
chk("js", g(re_detect(ch, re_compile(e, dialect="js"), anchor="full")))
chk("js x", g(re_detect(ch, re_compile(e, dialect="js", flags="x"), anchor="full")))
chk("literal agree", g(re_detect(ch, ch, literal=TRUE, anchor="full")))
chk("u flag", g(re_detect(ch, e, anchor="full", flags="xu")))
chk("i flag", g(re_detect(ch, e, anchor="full", flags="xi")))
# does the escaped only match itself (not something else)?
chk("no other ascii match", sapply(seq_len(127), function(i) sum(re_detect(ch[1:127], e[i], anchor="full")) == 1))
# bytes subjects
chb <- ch; Encoding(chb) <- "bytes"
r <- vapply(seq_along(ch), function(i) tryCatch(re_detect(chb[i], e[i], anchor="full"), error=function(e) NA), NA)
chk("bytes subject", r)
r <- vapply(seq_along(ch), function(i) tryCatch(re_detect(charToRaw(ch[i]), e[i], anchor="full"), error=function(e) NA), NA)
chk("raw subject", r)
t(re_detect(charToRaw("a\u0085b"), re_escape("a\u0085b"))); t(re_detect(charToRaw("a b"), re_escape("a b"))); t(re_detect(charToRaw("a b"), "a b", literal=TRUE))
t(re_detect(charToRaw("aéb"), re_escape("aéb")))
# value matrix
t(re_escape(c(a="a.b", b=NA, a="c"))); t(re_escape(character())); t(re_escape(NA)); t(re_escape(NULL)); t(re_escape(1.5)); t(re_escape(factor("a.b")))
lat <- iconv("café.", "UTF-8", "latin1"); r <- t(re_escape(lat)); print(Encoding(r)); t(re_detect(lat, r, anchor="full"))
b <- "\xff."; Encoding(b) <- "bytes"; r <- t(re_escape(b)); print(Encoding(r)); t(re_detect(b, r, anchor="full")); t(re_detect(charToRaw("\xffa"), r, anchor="full"))
bad <- "\xff."; r <- t(re_escape(bad)); 
t(re_escape("a\nb\tc d#e\\f\r\f\v")); t(re_escape("\\Qa\\E")); t(re_detect("\\Qa\\E", re_escape("\\Qa\\E"), anchor="full"))
t(re_escape(matrix(c("a.","b"),1)))
# use in class / replacement?  escape then within char class
t(re_detect(c("]", "^", "-", "\\", "a"), paste0("^[", re_escape("]^-\\"), "]$")))
t(re_detect(c(" ", "#", "a"), paste0("^[", re_escape(" #"), "]$"), flags="xx"))
t(re_detect(c("\n", "\t", "\u0085"," ","a"), paste0("^[", re_escape("\n\t\u0085 "), "]$"), flags="xx"))

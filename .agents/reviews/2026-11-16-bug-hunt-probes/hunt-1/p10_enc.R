source("pre.R")
cat(Sys.getlocale(), "\n")
bad <- "\xff."
r <- t(re_escape(bad)); if (!is.null(r)) {print(charToRaw(r)); print(Encoding(r))}
t(re_detect("<ff>.", re_escape(bad), anchor="full"))
t(re_detect(bad, bad, literal=TRUE)); t(re_detect("<ff>.", bad, literal=TRUE)); t(re_compile(bad)); 
t(re_replace("a", "a", bad)); t(re_replace(c("a","b"), "a", c(bad, "x"))); r <- t(re_replace("a", "a", function(m) bad)); if(!is.null(r)) print(charToRaw(r))
t(re_expand("a", "a", bad)); t(re_detect(bad, "a")); t(re_detect(c(bad,"a"), c("a","a")))
t(re_compile("a", flags = bad))
js <- re_compile(re_escape("a b"), dialect="js"); t(re_detect("a b", js)); t(as.character(js))
u <- "café über \U0001F600!"; lat <- iconv("café über", "UTF-8", "latin1")
byt <- u; Encoding(byt) <- "bytes"
show <- function(r) { if (is.data.frame(r)) r <- as.list(r); if (is.list(r)) r <- unlist(r); print(r); print(Encoding(r)) }
show(t(re_extract(c(u, lat, "abc"), "\\w+$|\\w+!?$")))
show(t(re_extract(c(u, lat, "abc"), c("\\S+$","\\S+$","\\S+$"))))
show(t(re_extract_all(c(u, lat), "\\S+")))
show(t(re_split(c(u, lat), " ")))
show(t(re_match(c(u, lat), "(\\S+) (?<s>\\S+)")))
show(t(re_replace(c(u, lat, "abc"), "\\s", "_")))
show(t(re_expand(c(u, lat, "abc"), "(\\S)\\S*", "$1")))
show(t(re_extract(byt, "\\S+")))
show(t(re_extract(c(byt, "abc", NA), "\\w+")))
show(t(re_extract(c(byt, lat), "\\S+$")))   # mixed bytes + latin1: what happens to latin1 element?
t(re_detect(c(byt, lat), "ü")); t(re_detect(c(byt, lat), lat)); t(re_count(c(byt, u), "."))
t(re_locate(c(byt, u), "!")); t(re_locate(c(byt, u), "!", bytes=TRUE)); t(re_locate(u, "!"))
t(re_detect(charToRaw(u), "é")); t(re_detect(charToRaw(lat), lat)); t(re_detect(charToRaw(lat), "\\xe9")); t(re_detect(list(charToRaw(lat)), "é"))
bp <- "\xe9"; Encoding(bp) <- "bytes"; t(re_detect(charToRaw(lat), bp)); t(re_detect(lat, bp)); t(re_detect(c(lat,"a"), c(bp,"a"))); t(re_compile(bp)); t(re_detect(byt, bp))
t(re_detect(u, "\\C")); t(re_detect(byt, "\\C")); t(re_detect(byt, "(*UTF)a")); t(re_detect(byt, re_compile("é", flags="i")));  t(re_detect(byt, re_compile("CAF", flags="i")))
t(re_detect(byt, re_compile("caf.{2} ", dialect="js"))); t(re_detect(byt, re_compile("caf. ")))
t(re_detect(byt, re_compile(c("caf.. "), jit=FALSE)))
t(re_detect(c(byt,byt), re_compile(c("caf.. ", NA))))
# Encoding mark for ASCII/empty
show(t(re_replace(c("abc", "", NA), "b", "é"))); show(t(re_extract(c("aé"), c("a")))); show(t(re_extract_all(c("aéa"), c("a|é"))))
# names in match frames of non-ASCII group names
r <- t(re_match("x1", "(?<größe>\\d)")); print(Encoding(names(r))); t(re_extract("x1", "(?<größe>\\d)", group="größe")); t(re_extract("x1", "(?<größe>\\d)", group=iconv("größe","UTF-8","latin1")))
t(re_extract(c("x1","x2"), rep("(?<größe>\\d)",2), group=iconv("größe","UTF-8","latin1")))
t(re_replace("x1", "(?<größe>\\d)", function(m) m[["größe"]])); t(re_info(re_compile("(?<größe>\\d)"))$group_names)
t(re_replace("x1", "(?<größe>\\d)", "<${größe}>")); t(re_replace("x1", iconv("(?<größe>\\d)", "UTF-8","latin1"), iconv("<${größe}>","UTF-8","latin1")))
# flags marked / named
f <- "i"; names(f) <- "zz"; t(re_detect("A", "a", flags=f)); fb <- "i"; Encoding(fb) <- "bytes"; t(re_detect("A","a",flags=fb))
# pattern latin1 fast vs general
t(re_detect(c(u, lat), iconv("ü", "UTF-8", "latin1"))); t(re_detect(c(u, lat), rep(iconv("ü", "UTF-8", "latin1"), 2))); t(re_detect(c(u, lat), re_compile(iconv("ü", "UTF-8", "latin1"))))
t(Encoding(as.character(re_compile(iconv("ü", "UTF-8", "latin1"))))); t(re_info(re_compile(lat))$pattern == lat)

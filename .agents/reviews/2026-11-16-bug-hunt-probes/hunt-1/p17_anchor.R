source("pre.R")
t(re_detect(c("a.c","xa.c","a.cx","abc"), "a.c", literal=TRUE, anchor="full")); t(re_detect(c("a.c","xa.c","a.cx"), "a.c", literal=TRUE, anchor="start"))
t(re_detect(c("a\n","a"), "a$", anchor="full")); t(re_detect("aaa", "a*?", anchor="full")); t(re_detect("a\nb", "^b", anchor="start", flags="m")); t(re_detect("ab", "b|ab", anchor="full")); t(re_detect("ab", "a|ab", anchor="full"))
t(re_detect(c("ab","xab"), re_compile("ab"), anchor="start")); t(re_detect(charToRaw("xab"), "ab", anchor="start")); t(re_detect(c("ab","xab"), c("ab","ab"), anchor="start", negate=TRUE))
t(re_detect(c("", NA), "", anchor="full")); t(re_detect("abc", "(?<=a)b", anchor="start")); t(re_detect("ab", "\\Kb", anchor="start"))
for (p in c("a\\c(|b", "a\\Q[\\E|b", "a\\Kb")) { r <- re_info(re_compile(p)); cat(p, " prefix=[", r$prefix, "] min=", r$min_length, " extract(b)=", re_extract("b", p), " extract(ab)=", re_extract("ab", p), "\n", sep="") }
t(re_match(c("x"), "(?<n>a)|(?<n>x)", proto=list(n=""), flags="J")); t(re_match("a", NA_character_, proto=list())); t(re_match(c("a",NA), "(a)", proto=list(q=1L)))
t(re_locate_all(c("aaaa", NA, "b"), "aa", overlap=TRUE, n=2)); t(re_locate_all(c("aaaa", NA, "b"), c("aa","a","b"), overlap=TRUE, n=2, bytes=TRUE))
t(re_count(c("aaaa"), "aa")); t(re_count("abc", ""));  t(re_count(list(charToRaw("aXa"), NULL), "a"))

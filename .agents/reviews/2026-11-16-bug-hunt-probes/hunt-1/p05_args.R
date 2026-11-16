source("pre.R")
lat <- iconv("café über a", "UTF-8", "latin1")
x <- c("a1", "bb22", NA)
# x types
t(re_detect(factor(c("a","b")), "a")); t(re_detect(1:3, "1")); t(re_detect(NA, "a")); t(re_detect(NULL, "a")); t(re_detect(list("a"), "a")); t(re_detect(Sys.Date(), "2"))
t(re_detect(list(charToRaw("a"), NULL, raw()), "a")); t(re_detect(raw(), "")); t(re_detect(charToRaw("abc"), "b"))
t(re_detect(c(a="a", b="b"), "a")); t(re_extract(c(a="a", b="b"), "a")); t(re_replace(c(a="a", b="b"), "a", "x")); t(re_locate(c(a="a", b="b"), "a")); t(re_split(c(a="a", b="b"), "a"))
t(re_detect(matrix(c("a","b","c","a"),2), "a"))
# pattern types
t(re_detect(x, NA)); t(re_detect(x, NA_character_)); t(re_detect(x, character())); t(re_detect(x, c("a","b"))); t(re_detect(x, factor("a"))); t(re_detect(x, 1)); t(re_detect(x, NULL)); t(re_detect(x, list("a")))
t(re_detect(x, c("a", NA, "b"))); t(re_count(x, c("\\d", NA, "b"))); t(re_extract(x, c("\\d", NA, "b"))); t(re_locate(x, c("\\d", NA, "b"))); t(re_locate_all(x, c("\\d", NA, "b")))
t(re_match(x, c("(\\d)", NA, "b"))); t(re_match_all(x, c("(\\d)", NA, "b"))); t(re_replace(x, c("(\\d)", NA, "b"), "!")); t(re_split(x, c("(\\d)", NA, "b"))); t(re_expand(x, c("(\\d)", NA, "b"), "$0")); t(re_extract_all(x, c("\\d", NA, "b")))
t(re_extract_all(x, NA_character_)); t(re_match(x, NA_character_)); t(re_match_all(x, NA_character_)); t(re_locate_all(x, NA_character_)); t(re_split(x, NA_character_)); t(re_replace(x, NA_character_, "z")); t(re_replace(x, NA_character_, function(m) "z"))
# anchor/negate
t(re_detect(x, "a", anchor=c("none","start","full"))); t(re_detect(x, "a", anchor="st")); t(re_detect(x, "a", anchor=NA)); t(re_detect(x, "a", anchor=1)); t(re_detect(x, "a", negate=NA)); t(re_detect(x, "a", negate="yes")); t(re_detect(x, "a", negate=c(TRUE,FALSE)))
t(re_detect(c("ab","b","a\n"), "a|ab", anchor="full")); t(re_detect(c("ab","b", NA), "a", negate=TRUE))
# n
for (n in list(0, 1, 2, 2.5, -1, NA, NA_integer_, Inf, -Inf, 2^31, 2^53, 1e300, "2", TRUE, NULL, c(1,2), 2L, NaN)) {
  cat("\n#### n ="); str(n)
  t(re_extract_all("a1b2c3", "\\d", n=n)); t(re_locate_all("a1b2c3", "\\d", n=n)); t(re_match_all("a1b2c3", "(\\d)", n=n)); t(re_replace("a1b2c3", "\\d", "#", n=n)); t(re_split("a1b2c3", "\\d", n=n)); t(re_replace("a1b2c3", "\\d", function(m) rep("#", nrow(m)), n=n))
  t(re_split(c("a1b2c3",NA), c("\\d","x"), n=n)); t(re_extract_all(c("a1b2c3",NA), c("\\d","x"), n=n))
}
# group
for (g in list(0L, 1, 2, 3, 1.5, -1, NA, "n", "", "zz", "0", "1", TRUE, NULL, c(1,2), 2^31, 2^53, Inf, NA_character_, factor("n"))) {
  cat("\n#### group ="); str(g)
  t(re_extract("a1b2", "(?<n>[a-z])(\\d)", group=g)); t(re_extract_all(c("a1b2","q"), c("(?<n>[a-z])(\\d)", "(q)"), group=g))
}
t(re_extract(c("ab","ba"), "(?<n>a)|(?<n>b)", group="n", flags="J")); t(re_extract(c("ab","ba"), rep("(?<n>a)|(?<n>b)",2), group="n", flags="J"))
t(re_match(c("ab","ba"), "(?<n>a)|(?<n>b)", flags="J")); t(re_match(c("ab","ba"), rep("(?<n>a)|(?<n>b)",2), flags="J")); t(re_match(c("ab","ba"), re_compile("(?<n>a)|(?<n>b)", flags="J")))
t(re_match_all(c("ab","ba"), "(?<n>a)|(?<n>b)", flags="J")); t(re_match_all(c("ab","ba"), rep("(?<n>a)|(?<n>b)",2), flags="J"))
t(re_replace(c("ab","ba"), "(?<n>a)|(?<n>b)", function(m) {print(m); toupper(m$n)}, flags="J"))
t(re_match(c("ab", "cd"), c("(?<x>a)(b)", "(c)(?<x>d)")))
t(re_match(c("ab", "cd", "e"), c("(a)(?<x>b)", "(?<x>c)(d)", "e")))
t(re_match_all(c("ab"), "(?<element>a)(?<match>b)")); t(re_replace("ab", "(?<element>a)(?<match>b)", function(m) {print(m); "z"}))
t(re_replace("ab", "(?<el>a)(?<mat>b)", function(m) {print(m); "z"}))
# flags/literal/bytes/overlap
t(re_detect("A", "a", flags="i")); t(re_detect("A", "a", flags=NA)); t(re_detect("A", "a", flags=c("i","m"))); t(re_detect("A", "a", literal=NA)); t(re_detect("A.", "a.", literal=TRUE, flags="i")); t(re_detect("A.", "a.", literal=TRUE, flags="x")); t(re_detect("A", "a", flags="ii"))
t(re_detect(c("A","b"), c("a","B"), flags="i")); t(re_detect(c("a.","ab"), c("a.","a."), literal=TRUE))
t(re_locate("aé1", "\\d", bytes=NA)); t(re_locate("aé1", "\\d", bytes=TRUE)); t(re_locate("aé1", "\\d", bytes="TRUE")); t(re_locate(lat, "a$", bytes=TRUE)); t(re_locate(lat, "a$")); t(re_locate_all(lat, "ü", bytes=TRUE)); t(nchar(lat, "bytes"))
t(re_locate_all("aaaa", "aa", overlap=NA)); t(re_locate_all("aaaa", "aa", overlap=1)); t(re_locate_all("éééé", "éé", overlap=TRUE, bytes=TRUE)); t(re_locate_all("abc", "", overlap=TRUE)); t(re_locate_all("abc", "")); t(re_locate_all("abc", "b*", overlap=TRUE))
# empty x shapes
str(re_detect(character(), "a")); str(re_count(character(), "a")); str(re_locate(character(), "a")); str(re_locate_all(character(), "a")); str(re_extract(character(), "a")); str(re_extract_all(character(), "a")); str(re_match(character(), "(a)")); str(re_match_all(character(), "(a)")); str(re_replace(character(), "a", "b")); str(re_replace(character(), "a", function(m) "b")); str(re_expand(character(), "a", "b")); str(re_split(character(), "a"))
str(re_match_all(character(), character())); str(re_locate_all(character(), character())); str(re_match(c("a","b"), "x")); str(re_match_all(c("a","b"), "x")); str(re_match_all(c("a","b"), "(x)")); str(re_locate_all("a","x")); str(re_match_all(c("a",NA), "a"));str(re_match(c("a",NA), "a"))
str(re_match_all(c("a",NA), c("a","a"))); str(re_locate(NA_character_, "a")); str(re_locate(character(), character()))

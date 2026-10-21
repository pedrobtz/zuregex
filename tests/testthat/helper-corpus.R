# The shared parity corpus (design section 9). Functions, not file-scope
# objects, so every test builds its own copy.

parity_subjects <- function() {
  c(
    "",
    "a",
    "abc",
    "aaa",
    "abab",
    "Hello, World!",
    "hello world",
    "foo123bar",
    "2026-10-21",
    "x=1; y=22; z=333",
    "line one\nline two\n",
    "tab\tseparated\tvalues",
    "  padded  ",
    "CamelCaseWord",
    "snake_case_word",
    "a.b*c+d?",
    "(parens) [brackets] {braces}",
    "été",
    "naïve café",
    "日本語のテキスト",
    "emoji \U0001F600 here",
    "Αθήνα",
    "mixed ÉCOLE école",
    "repeat repeat repeat"
  )
}

# Patterns whose meaning is the same in PCRE2 and in ICU, which stringr
# uses, over the corpus above. Differences are tested separately as GAPs.
parity_patterns <- function() {
  c(
    "a",
    "abc",
    "^a",
    "c$",
    "^$",
    "a+",
    "a*",
    "a?b",
    "[aeiou]",
    "[^aeiou ]+",
    "[0-9]+",
    "\\d{2,3}",
    "\\s",
    "\\S+",
    "o\\b",
    "\\bw",
    "(ab)+",
    "(a|b)c",
    "x=(\\d+)",
    "foo(?=\\d)",
    "(?<=foo)\\d",
    "(?<!a)b",
    "a(?!b)",
    "\\.",
    "\\(",
    "[.*+?]",
    "repeat\\s+repeat",
    "(?i)hello",
    "(?i)world",
    "é",
    "[à-ÿ]",
    "caf.",
    "日本",
    ".",
    "^.{3}$",
    "\U0001F600",
    "θ",
    "e$",
    "(\\w)\\1",
    "^\\s+|\\s+$",
    "one\\nline",
    "two$"
  )
}

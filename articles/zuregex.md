# Get started with zuregex

``` r

library(zuregex)
```

We take a few lines of a web server’s log and work through them: find
the lines that match, pull out parts of them, turn them into a data
frame, rewrite them and cut them up. After that you know the main
`re_*()` functions and the rules they share. Moving from base R or
stringr, limits on untrusted patterns and the C API each have their own
article, listed at the end.

## Detect matches

The log is a character vector. Its last element is not a log line, so we
can see what a string that does not match gives.

``` r

log <- c(
  "2026-10-21 08:15:02 GET /index.html 200 512",
  "2026-10-21 08:15:09 POST /login 302 0",
  "2026-10-21 08:16:44 GET /missing 404 128",
  "not a log line"
)
```

Every function takes the strings first, as `x`, and then a **pattern**:
a regular expression in PCRE2’s syntax, which is the syntax of base R’s
`perl = TRUE`.
[`re_detect()`](https://pedrobtz.github.io/zuregex/reference/re_detect.md)
says which elements match.

``` r

re_detect(log, "GET")
#> [1]  TRUE FALSE  TRUE FALSE
```

One pattern is used for every element. The other choice is one pattern
per element, as long as `x`. Here each line is tested for its own status
code, and only the second line has the one asked for.

``` r

re_detect(log, c("404", "302", "200", "500"))
#> [1] FALSE  TRUE FALSE FALSE
```

A pattern of any other length is an error: zuregex never recycles one.

## Extract matches

[`re_extract()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
returns the text of the first match in each element, and `NA` where
there is none.

``` r

re_extract(log, "/\\S+")
#> [1] "/index.html" "/login"      "/missing"    NA
```

Parentheses in a pattern make a **group**, a part of the match you can
ask for by itself. `group` picks one, by number or, for a group written
`(?<name>...)`, by name. This returns the status code alone, without the
spaces the pattern needs around it.

``` r

re_extract(log, " (?<status>\\d{3}) ", group = "status")
#> [1] "200" "302" "404" NA
```

## Capture groups as columns

[`re_match()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
returns every group at once, as a data frame with one row per element. A
named group gives its name to its column.

``` r

pattern <- "(?<time>\\S+ \\S+) (?<method>[A-Z]+) (?<path>\\S+) (?<status>\\d+)"
re_match(log, pattern)
#>                  time method        path status
#> 1 2026-10-21 08:15:02    GET /index.html    200
#> 2 2026-10-21 08:15:09   POST      /login    302
#> 3 2026-10-21 08:16:44    GET    /missing    404
#> 4                <NA>   <NA>        <NA>   <NA>
```

The columns are character. `proto` gives them types, as it does for
[`utils::strcapture()`](https://rdrr.io/r/utils/strcapture.html): a data
frame whose columns are examples of the type wanted. Look at `status`,
now an integer.

``` r

proto <- data.frame(time = "", method = "", path = "", status = 0L)
str(re_match(log, pattern, proto = proto))
#> 'data.frame':    4 obs. of  4 variables:
#>  $ time  : chr  "2026-10-21 08:15:02" "2026-10-21 08:15:09" "2026-10-21 08:16:44" NA
#>  $ method: chr  "GET" "POST" "GET" NA
#>  $ path  : chr  "/index.html" "/login" "/missing" NA
#>  $ status: int  200 302 404 NA
```

[`re_match()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
looks at the first match in each element.
[`re_match_all()`](https://pedrobtz.github.io/zuregex/reference/re_extract.md)
returns a row for every match, with `element` and `match` saying where
each came from. Each of the first three lines has two numbers at its
end, and the last line has no rows.

``` r

re_match_all(log, " (?<number>\\d+)(?= |$)")
#>   element match number
#> 1       1     1    200
#> 2       1     2    512
#> 3       2     1    302
#> 4       2     2      0
#> 5       3     1    404
#> 6       3     2    128
```

## Replace and split

[`re_replace()`](https://pedrobtz.github.io/zuregex/reference/re_replace.md)
replaces every match with a **template**, in which `${name}` or `$1`
stands for a group. Here the date is turned round, and the line with no
date comes back unchanged.

``` r

re_replace(log, "^(?<y>\\d+)-(?<m>\\d+)-(?<d>\\d+)", "${d}/${m}/${y}")
#> [1] "21/10/2026 08:15:02 GET /index.html 200 512"
#> [2] "21/10/2026 08:15:09 POST /login 302 0"      
#> [3] "21/10/2026 08:16:44 GET /missing 404 128"   
#> [4] "not a log line"
```

Templates can do more than this, such as defaults and case changes;
[`?re_replace`](https://pedrobtz.github.io/zuregex/reference/re_replace.md)
lists the syntax.

[`re_split()`](https://pedrobtz.github.io/zuregex/reference/re_split.md)
cuts each element at the matches, and returns a list with a character
vector of pieces per element.

``` r

re_split(log[1:2], " ")
#> [[1]]
#> [1] "2026-10-21"  "08:15:02"    "GET"         "/index.html" "200"        
#> [6] "512"        
#> 
#> [[2]]
#> [1] "2026-10-21" "08:15:09"   "POST"       "/login"     "302"       
#> [6] "0"
```

## Compile a pattern once

So far each pattern was a string.
[`re_compile()`](https://pedrobtz.github.io/zuregex/reference/re_compile.md)
turns one into an **`re` object**, which carries its flags with it and
which every function takes in place of the string. The flag `i` ignores
case, so this lower-case pattern finds the log’s `GET`.

``` r

get <- re_compile("\\bget\\b", flags = "i")
get
#> <re[1]>
#> [1] /\bget\b/i
re_detect(log, get)
#> [1]  TRUE FALSE  TRUE FALSE
```

You do not need
[`re_compile()`](https://pedrobtz.github.io/zuregex/reference/re_compile.md)
for speed. Pattern strings go through a cache, so a string used again is
not compiled again; see
[`?re_cache_size`](https://pedrobtz.github.io/zuregex/reference/re_cache_size.md).

## When a pattern is wrong

The most common mistake is a pattern that is not valid. This one never
closes the group it opens.

``` r

re_match(log, "(?<time>\\S+ \\S+ (?<method>[A-Z]+)")
#> Error in `re_match()`:
#> ! Can't compile pattern: missing closing parenthesis at character 34.
#>   (?<time>\S+ \S+ (?<method>[A-Z]+)
#>                                    ^
```

The error names the problem and marks where in the pattern PCRE2 found
it. Like every error zuregex raises, it has a class, here
`zuregex_error_compile`, so
[`tryCatch()`](https://rdrr.io/r/base/conditions.html) can handle it.

## Where next

- [Move from base R and
  stringr](https://pedrobtz.github.io/zuregex/articles/from-base-r.html)
  maps the functions you know onto these, and shows what behaves
  differently.
- [Bound the work of a
  match](https://pedrobtz.github.io/zuregex/articles/limits.html) is for
  patterns or input you do not trust.
- [Link to zuregex from
  C](https://pedrobtz.github.io/zuregex/articles/c-api.html) uses the
  same PCRE2 from another package’s C code.
- [Design and
  motivation](https://pedrobtz.github.io/zuregex/articles/design.html)
  explains why zuregex exists next to base R’s own PCRE2, and what it
  leaves out.
- The [reference index](https://pedrobtz.github.io/zuregex/reference/)
  lists every function, including the ones this page skipped: counting,
  locating, escaping, and the thread and cache controls.

# Benchmarks zuregex against base R's perl = TRUE engine and stringi, for
# vignettes/articles/benchmarks.Rmd (#66). Results are written to
# vignettes/articles/benchmarks.csv, with the machine and versions in
# vignettes/articles/benchmarks-info.csv, and the article only reads them,
# so building the site needs neither stringi nor bench.
#
# Run it from the package root against an installed build, not
# devtools::load_all(), which compiles without optimisation:
#
#   R CMD INSTALL --preclean --library=/tmp/zr-bench .
#   Rscript tools/bench/run.R /tmp/zr-bench
#
# Each case first checks that the three engines agree, then times each one
# with bench::mark() and keeps the median.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0) {
  .libPaths(c(args[[1]], .libPaths()))
}
for (pkg in c("zuregex", "stringi", "bench")) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("tools/bench/run.R needs ", pkg, call. = FALSE)
  }
}
library(zuregex)

# The corpus of tests/testthat/helper-bench.R: synthetic log lines of about
# 64 ASCII characters, with an id, an e-mail-like token, separators and, on
# half of them, a phone number.
bench_corpus <- function(n) {
  set.seed(1)
  words <- c(
    "alpha",
    "beta",
    "gamma",
    "delta",
    "error",
    "warn",
    "info",
    "user",
    "login",
    "timeout"
  )
  x <- sprintf(
    "%s %s id=%d user%d@host%d.com %s; %s, call 555-%04d",
    sample(words, n, TRUE),
    sample(words, n, TRUE),
    sample.int(1e6, n, TRUE),
    sample.int(999, n, TRUE),
    sample.int(50, n, TRUE),
    sample(words, n, TRUE),
    sample(words, n, TRUE),
    sample.int(9999, n, TRUE)
  )
  no_phone <- sample.int(n, n / 2)
  x[no_phone] <- sub("call 555-\\d+", "no phone", x[no_phone])
  x
}

x <- bench_corpus(50000)
one <- x[[1]]
phone <- "\\b555-\\d{4}\\b"
email <- "user(\\d+)@host(\\d+)\\.com"
sep <- "[,;] *"

# Each case: a label, the input size, and one function per engine. The
# `agree` function turns each engine's result into one comparable value.
cases <- list(
  list(
    task = "Detect",
    size = "50,000 strings",
    zuregex = function() re_detect(x, phone),
    base = function() grepl(phone, x, perl = TRUE),
    stringi = function() stringi::stri_detect_regex(x, phone),
    agree = identity
  ),
  list(
    task = "Count matches",
    size = "50,000 strings",
    zuregex = function() re_count(x, "\\d+"),
    base = function() {
      m <- gregexpr("\\d+", x, perl = TRUE)
      vapply(m, function(p) sum(p > 0), 0L)
    },
    stringi = function() stringi::stri_count_regex(x, "\\d+"),
    agree = as.integer
  ),
  list(
    task = "Locate the first match",
    size = "50,000 strings",
    zuregex = function() re_locate(x, email)[, "start"],
    base = function() {
      s <- regexpr(email, x, perl = TRUE)
      as.integer(ifelse(s > 0, s, NA))
    },
    stringi = function() stringi::stri_locate_first_regex(x, email)[, 1],
    agree = as.integer
  ),
  list(
    task = "Extract every match",
    size = "50,000 strings",
    zuregex = function() re_extract_all(x, "\\d+"),
    base = function() regmatches(x, gregexpr("\\d+", x, perl = TRUE)),
    stringi = function() stringi::stri_extract_all_regex(x, "\\d+"),
    agree = function(v) lapply(v, function(e) e[!is.na(e)])
  ),
  list(
    task = "Capture groups",
    size = "50,000 strings",
    zuregex = function() re_match(x, email),
    base = function() {
      utils::strcapture(email, x, data.frame(a = "", b = ""), perl = TRUE)
    },
    stringi = function() stringi::stri_match_first_regex(x, email),
    agree = function(v) {
      v <- as.matrix(as.data.frame(v))
      unname(v[, (ncol(v) - 1):ncol(v)])
    }
  ),
  list(
    task = "Replace every match",
    size = "50,000 strings",
    zuregex = function() re_replace(x, email, "$2:$1"),
    base = function() gsub(email, "\\2:\\1", x, perl = TRUE),
    stringi = function() stringi::stri_replace_all_regex(x, email, "$2:$1"),
    agree = identity
  ),
  list(
    task = "Split",
    size = "50,000 strings",
    zuregex = function() re_split(x, sep),
    base = function() strsplit(x, sep, perl = TRUE),
    stringi = function() stringi::stri_split_regex(x, sep),
    agree = identity
  ),
  list(
    task = "Detect, one string",
    size = "1 string",
    zuregex = function() re_detect(one, email),
    base = function() grepl(email, one, perl = TRUE),
    stringi = function() stringi::stri_detect_regex(one, email),
    agree = identity
  )
)

engines <- c("zuregex", "base", "stringi")
rows <- list()
for (case in cases) {
  results <- lapply(engines, function(e) case$agree(case[[e]]()))
  for (k in 2:3) {
    if (
      !isTRUE(all.equal(results[[1]], results[[k]], check.attributes = FALSE))
    ) {
      stop(
        case$task,
        ": zuregex and ",
        engines[[k]],
        " disagree",
        call. = FALSE
      )
    }
  }
  timing <- bench::mark(
    zuregex = case$zuregex(),
    base = case$base(),
    stringi = case$stringi(),
    check = FALSE,
    min_iterations = 10,
    time_unit = "ms"
  )
  rows[[length(rows) + 1]] <- data.frame(
    task = case$task,
    size = case$size,
    engine = engines,
    median_ms = as.numeric(timing$median)
  )
  message(case$task, ": done")
}
results <- do.call(rbind, rows)

info <- zuregex_info()
cpu <- tryCatch(
  if (Sys.info()[["sysname"]] == "Darwin") {
    system("sysctl -n machdep.cpu.brand_string", intern = TRUE)
  } else {
    sub(
      ".*: ",
      "",
      grep("model name", readLines("/proc/cpuinfo"), value = TRUE)[[1]]
    )
  },
  error = function(e) NA_character_
)
machine <- data.frame(
  key = c(
    "date",
    "zuregex",
    "pcre2",
    "jit",
    "threads",
    "R",
    "base_pcre2",
    "stringi",
    "icu",
    "platform",
    "cpu"
  ),
  value = c(
    format(Sys.Date()),
    as.character(utils::packageVersion("zuregex")),
    info$pcre2_version,
    as.character(info$jit_usable),
    as.character(info$threads),
    R.version.string,
    unname(extSoftVersion()[["PCRE"]]),
    as.character(utils::packageVersion("stringi")),
    stringi::stri_info()$ICU.version,
    R.version$platform,
    cpu
  )
)

out <- file.path("vignettes", "articles")
utils::write.csv(results, file.path(out, "benchmarks.csv"), row.names = FALSE)
utils::write.csv(
  machine,
  file.path(out, "benchmarks-info.csv"),
  row.names = FALSE
)
message("wrote ", file.path(out, "benchmarks.csv"))

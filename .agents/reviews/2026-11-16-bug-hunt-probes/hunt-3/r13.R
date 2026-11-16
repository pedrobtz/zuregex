.libPaths("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz-zuregex/e53874e6-da4a-401d-a173-3b05192b4f61/scratchpad/hunt/lib"); library(zuregex)
t <- function(label, expr) { r <- tryCatch({ v <- expr; paste(capture.output(str(v, give.attr = FALSE)), collapse = " | ") }, error = function(e) paste0("ERROR<", class(e)[1], "> ", conditionMessage(e))); cat(sprintf("%-50s %s\n", label, substr(r, 1, 200))) }
cs <- function() unlist(zuregex:::cache_stats())
r <- re_compile(c(one = "\\d", two = "[a-z]"))
q <- r; q$one <- NULL; t("after q$one <- NULL: class/len/attr len", c(class(q), length(q), length(attr(q, "pattern")))); t("  use it", re_detect("a", q)); t("  print it", capture.output(print(q)))
cat("== 65536-character straddle\n")
for (n in c(65535, 65536, 65537)) { re_cache_clear(); p <- strrep("a", n); s0 <- cs(); a <- re_detect(c(p, "b"), p); b <- re_detect(c(p, "b"), p); s1 <- cs(); cat(n, "chars: result", a, "| size", s1["size"], "hits +", s1["hits"] - s0["hits"], "misses +", s1["misses"] - s0["misses"], "\n") }
for (n in c(65536, 65537)) { re_cache_clear(); p <- strrep("é", n); s0 <- cs(); a <- re_detect(c(p, "b"), p); b <- re_detect(c(p, "b"), p); s1 <- cs(); cat(n, "2-byte chars: result", a, "| size", s1["size"], "hits +", s1["hits"] - s0["hits"], "misses +", s1["misses"] - s0["misses"], "\n") }
re_cache_clear(); p <- strrep("a", 65537); rr <- re_compile(p); t("re of 65537 chars, cache size", cs()["size"]); t("  works after gc", { gc(); re_detect(p, rr) })
cat("== interrupt\n")
x <- rep(strrep("a", 26), 400); pid <- Sys.getpid()
system(sprintf("(sleep 1; kill -INT %d) &", pid))
t0 <- Sys.time(); res <- tryCatch(re_detect(x, "(a+)+$b", limits = re_limits(on_limit = "na")), interrupt = function(e) "INTERRUPTED", warning = function(w) "limit warning", error = function(e) conditionMessage(e))
cat("SIGINT sent at 1 s; call returned after", round(as.numeric(Sys.time() - t0, units = "secs"), 1), "s with:", if (is.character(res)) res else "a full result", "\n")

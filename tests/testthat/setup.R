# CRAN's machines allow two threads per check. Every test runs under that
# cap; results must not depend on it (design section 6.6), and
# test-threads.R checks that they do not.
old_threads <- re_threads(2)
withr::defer(re_threads(old_threads), teardown_env())

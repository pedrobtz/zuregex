# Assurance

How this package meets the shared `assurance.md` rules. CI checks this
file (r-actions `assurance.yml`), so keep the headings and table
columns as they are.

- **Statuses:** a cell is a fact, `gap #<issue>` or `n/a: <reason>`.
- **Kinds:** delete the ones that do not apply.
- **Tables:** delete a table only when no kind requires it. Delete the
  example rows.

## Kinds

`compiled` `untrusted-input` `spec` `lifecycle`

## Required checks

`Where` names the workflow file under `.github/workflows/` that runs the
check. Add `(own)` when that workflow is the package's own rather than a
call to r-actions.

| Check         | Status    | Where              |
| ------------- | --------- | ------------------ |
| sanitizers    | done      | native-checks.yaml |
| valgrind      | done      | native-checks.yaml |
| rchk          | done      | native-checks.yaml |
| gctorture     | done      | native-checks.yaml |
| analyzers     | done      | native-checks.yaml |
| alloc-failure | gap #134 |                    |
| mutation      | gap #135 |                    |
| fuzz          | gap #136 | fuzz.yaml          |
| fuzz-reach    | gap #137 | fuzz.yaml          |

`fuzz.yaml` runs `tools/fuzz/harness.c` under ASan and UBSan, but the
harness fails only on a crash or a sanitizer report: it compares no
result, so it is not yet an oracle. `fuzz.yml` reports the corpus's reach,
but `fuzz.yaml` sets no `reach-floor`, so a harness that stops reaching
code never fails.

## Boundaries

One row per boundary the package crosses. An oracle knows the answer:

- a conformance suite or test vectors;
- a reference implementation;
- a round trip;
- equivalent inputs compared;
- the bytes the other side received.

"No crash" is not an oracle.

<!-- markdownlint-disable MD013 -->
| Boundary | Oracle | Carried by |
| --- | --- | --- |
| Pattern syntax to match, UTF-8, through the C API | PCRE2's own `testoutput4`: every group's bytes against what `pcre2test` printed, and compile errors; JIT only; 349 cases skipped and listed | tests/testthat/test-pcre2-testdata.R, tools/pcre2-testdata/convert.py, tools/pcre2-testdata/skipped.tsv |
| Pattern syntax to match, bytes, through the C API | PCRE2's own `testoutput1` with `ZR_BYTES`; JIT only | tests/testthat/test-pcre2-testdata.R, tests/testthat/helper-pcre2.R |
| The same corpus through the interpreter | none: every case runs with JIT | gap #50 |
| The same corpus through the R verbs | none: the corpus reaches only `zr_match()`, never `re_locate_all()` or `re_match()` and their offset conversion | gap #138 |
| Pattern to match, R verbs, character subjects | base R `perl = TRUE` and stringr on the parity corpus, with each difference marked `# GAP` | tests/testthat/helper-corpus.R, test-detect.R, test-locate.R, test-capture.R |
| Pattern to match, bytes and raw subjects | none: raw and bytes strings are compared only with each other | gap #139 |
| Per-element patterns | `stringr::str_detect()` vectorised over patterns, for `re_detect()` only | tests/testthat/test-detect.R; other verbs gap #140 |
| Literal patterns | base R `fixed = TRUE` for detect, replace, extract and locate | tests/testthat/test-flags.R |
| `dialect = "js"`, syntax and iteration | none: expected values written by hand | gap #141 |
| Iteration, PCRE2's empty-match rule | stringr `str_locate_all()` and `str_count()`, and Python `re.sub()` and `re.split()` | tests/testthat/test-locate.R, test-python.R, test-replace.R |
| Iteration, `overlap = TRUE` | none: expected values written by hand | gap #142 |
| Byte offsets to one-based character offsets | `regexpr(perl = TRUE)` and stringr on non-ASCII subjects | tests/testthat/test-locate.R |
| Captures, unset groups and `proto` typing | stringr `str_match()`, `str_match_all()` and `str_extract()`, `regmatches()` and `utils::strcapture()` | tests/testthat/test-capture.R |
| Replacement templates, PCRE2 extended syntax | `$`-free templates against `gsub()`, `sub()` and stringr; six Python `re.sub()` cases; every other form written by hand | tests/testthat/test-replace.R, test-python.R; PCRE2's `replace=` cases gap #143 |
| `re_split()` | Python `re.split()`, 15 cases recorded from `tools/oracles/python-re.py` | tests/testthat/test-python.R |
| `re_escape()` output | none yet: the round trip in test-escape.R matches with base R's `grepl()` and lets `$` be commented out under `x`, so it cannot fail; JS dialect, bytes and C locale untried | gap #171 |
| Encodings in: latin1, native and bytes to UTF-8 | known answers in a C and a Latin-1 locale, and on the fast and general paths; the invalid-pattern and template cases accept any error | tests/testthat/test-locale.R, test-prepare.R; classes gap #131; bytes mode gap #173 |
| `re` objects through `saveRDS()` | round trip, but only `re_info()` is compared; no restored object is matched with | gap #53 |
| C API offsets and substitution | the PCRE2 corpus above, and the consumer fixture against `re_locate(bytes = TRUE)` | tests/testthat/test-capi.R, tools/consumer/zuregexlink |
| Results at any thread count | one thread against the cap, and against base R | tests/testthat/test-threads.R |
| `re_info()` prefix and min_length | none: values written by hand | gap #169 |
| Replacement-function results into the output | type and length, one side only | gap #175 |
| JIT against the interpreter | none: the default engine is compared only with itself | gap #167 |
<!-- markdownlint-enable MD013 -->

## Objects

One row per object that outlives the call that made it. "Sequences" is
the test of its out-of-order use (abort then read, use after end, use
after free). The guard columns name the test, or say why the guard
cannot apply.

<!-- markdownlint-disable MD013 -->
| Object | Sequences | Fork | Unwind | Owner |
| --- | --- | --- | --- | --- |
| `re` object: external pointers, each holding one reference to a `zuregex_pattern` | use after `re_cache_clear()` and `re_cache_size(0)`, `c()` and subsetting, edited attributes: test-cache.R, test-re.R; no random sequence gap #144; restored objects gap #53 | n/a: a forked child has its own copy of the reference counts, and its finalizers release only that copy | the pointer exists before the pattern, so an R error cannot leak a reference (src/compile.c); a replacement function that errors gap #145 | the finalizer releases the one reference; test-re.R under valgrind and ASan |
| Cache entry: one reference per slot | eviction, shrinking, size 0 and clearing with live `re` objects: test-cache.R; no random sequence gap #144 | n/a: process-local state, so a child changes only its copy; test-threads.R runs a cached pattern in a forked child | n/a: `src/cache.c` and `src/pattern.c` make no R calls | `evict()`, `cache_clear()` and `set_capacity()`; capacity is bounded to 256 in R |
| Pattern borrowed by the fast path | fast and general paths agree: test-prepare.R; nothing pins that no finalizer can evict it mid-call gap #146 | as for the cache entry | n/a: nothing after the borrow calls R code | the cache; lives for one `.Call` |
| C API `zr_pattern` | one fixed order in tools/fuzz/harness.c; edge cases in src/capi_test.c through test-capi.R; no model-based target gap #147 | n/a: holds no process state; a consumer's fork copies the handle | n/a: no R API in src/capi.c | `zr_free()` releases the one reference |
| C API `zr_match_data` | match data used with another pattern: test-capi.R; freed after its pattern, and reused after `zr_substitute()`, untested gap #148 | n/a: as for `zr_pattern` | n/a: no R API | `zr_match_data_free()` frees the match data and its context |
| The DLL, with live `re` objects across `library.dynam.unload()` | none | n/a: process-wide | none: unloading then `gc()` segfaults | gap #168 |
| Phase-2 arenas and result buffers (one call) | n/a: they do not outlive the call | a forked child runs on one thread: test-threads.R | phase 3 runs under `R_ExecWithCleanup()`; the error description is built before it, so an allocation failure there leaks them (#43); no allocation-failure test gap #134 | `free_matches()`, `free_out()` and `free_caps()` on every path |
<!-- markdownlint-enable MD013 -->

## Limits

One row per limit the package enforces. "Straddled by" is the test of
`limit - 1`, `limit` and `limit + 1` on every path that reaches it.

<!-- markdownlint-disable MD013 -->
| Limit | Unit | Straddled by |
| --- | --- | --- |
| Cache capacity, 0 to 256, default 128 | patterns | values -1, 0, 256 and 257: test-cache.R; eviction at capacity 3 through `re_compile()` only; at 256 and through the fast path gap #149 |
| Longest cached pattern, 65,536 | characters (bytes for a bytes pattern) | 65,536 and 65,537 ASCII characters through `re_compile()`, 65,537 on the fast path: test-cache.R; multibyte and bytes patterns on every path gap #150 |
| JIT stack, PCRE2's built-in 32 KiB | bytes of stack | overflow at 400 KB only: test-limits.R; no size that must succeed, and ordinary 1 KB inputs fail gap #166 |
| `re_threads()` and `group` ranges | threads, group number | -1 and 1.5; -1, NA and `c(1, 2)`; the upper ends gap #195 |
| Compiled-size cap, `re_compile_size()`, default 16 MiB | compiled bytes | the default, a 458 MB pattern on every path and the C API, and one pattern under a cap of 1,000: test-compile-size.R; the cap - 1, cap, cap + 1 boundary gap #151 |
| PCRE2's compile limits: nesting 250, group names 128, lookbehind 255, 10,000 names | depth, bytes, characters, names | gap #152 |
| `re_limits(match =)` | match-function calls per search | 1,000 against a far larger need, on every verb, path, thread count and the C API: test-limits.R, test-threads.R, test-capi.R; the exact boundary under JIT and the interpreter, and the range ends 1 and 2^32 - 1 gap #153 |
| `re_limits(depth =, heap =)` | backtracking depth, KiB | depth 10 and heap 1 through an `re` object, interpreter only: test-limits.R; the fast path, the boundary, and heap's argument checks gap #154 |
| `n` in `*_all()`, `re_replace()` and `re_split()` | matches or split points | 0, 1, 2 and `Inf`, and -1 and 1.5 refused: test-replace.R, test-locate.R, test-capture.R, test-python.R; k - 1, k, k + 1 for k matches, and `NA` gap #155 |
| Serial threshold 16,384 and chunks of 64 | subject bytes, elements | the threshold pinned and set to 0: test-threads.R; inputs at the threshold and chunk boundaries gap #156 |
| `zr_substitute()` buffer, `zr_offsets()` and `zr_group_name()` group bounds | bytes with the NUL, group number | a buffer of 3 and of the exact size, group 9 and an unset group: test-capi.R; a buffer one byte short, groups -1, n and n + 1 gap #157 |
| Subjects, elements and results up to 2^31 - 1 | bytes, elements, bytes | none: each needs 2 GiB gap #158 |
<!-- markdownlint-enable MD013 -->

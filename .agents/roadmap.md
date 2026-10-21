# zuregex: roadmap

Status: draft 2026-10-21. Implements [design.md](design.md).
Target: v0.1.0, the first CRAN release.
Tracking: [v0.1.0 (#1)](https://github.com/pedrobtz/zuregex/issues/1), with one
sub-issue per stage;
[CRAN-submission (#14)](https://github.com/pedrobtz/zuregex/issues/14).

The design's §11 sketches nine stages. This roadmap keeps their order and
splits two of them so that each stage is one reviewable pull request: detect
and locate are separate stages, and the per-element pattern rule moves from
the compile stage to the first verb that pairs `pattern` with `x`. Package
identity, Full CI and v0.1.0 readiness bracket the feature work.

## Stages

<!-- markdownlint-disable MD013 -->

| Stage | Title | CI | Issue | Pull request | Done |
| --- | --- | --- | --- | --- | --- |
| 0 | [Package identity](#stage-0--package-identity) | quick | [#2](https://github.com/pedrobtz/zuregex/issues/2) | | 2026-10-21 |
| 1 | [Vendor PCRE2](#stage-1--vendor-pcre2) | full | [#3](https://github.com/pedrobtz/zuregex/issues/3) | | |
| 2 | [Compile, flags and the cache](#stage-2--compile-flags-and-the-cache) | full | [#4](https://github.com/pedrobtz/zuregex/issues/4) | | |
| 3 | [Detect and count](#stage-3--detect-and-count) | quick | [#5](https://github.com/pedrobtz/zuregex/issues/5) | | |
| 4 | [Locate](#stage-4--locate) | quick | [#6](https://github.com/pedrobtz/zuregex/issues/6) | | |
| 5 | [Extract and match](#stage-5--extract-and-match) | quick | [#7](https://github.com/pedrobtz/zuregex/issues/7) | | |
| 6 | [Replace, expand and split](#stage-6--replace-expand-and-split) | quick | [#8](https://github.com/pedrobtz/zuregex/issues/8) | | |
| 7 | [Limits](#stage-7--limits) | quick | [#9](https://github.com/pedrobtz/zuregex/issues/9) | | |
| 8 | [OpenMP](#stage-8--openmp) | full | [#10](https://github.com/pedrobtz/zuregex/issues/10) | | |
| 9 | [C API and consumers](#stage-9--c-api-and-consumers) | quick | [#11](https://github.com/pedrobtz/zuregex/issues/11) | | |
| 10 | [Full CI](#stage-10--full-ci) | full | [#12](https://github.com/pedrobtz/zuregex/issues/12) | | |
| 11 | [v0.1.0 readiness](#stage-11--v010-readiness) | full | [#13](https://github.com/pedrobtz/zuregex/issues/13) | | |

<!-- markdownlint-enable MD013 -->

## Stage 0 — Package identity

**Issue.** [#2](https://github.com/pedrobtz/zuregex/issues/2), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuregex/issues/1).

**CI.** `quick`. See the CI policy in `CLAUDE.md`.

**Goal.** The scaffold is a real package: it says what it is, who wrote it,
and its pull requests get a quick r-actions run that finishes in under five
minutes.

**Work.**

- `DESCRIPTION`: Title, Description, `Authors@R` with `cre`, `aut` and `cph`,
  `URL` and `BugReports`, `SystemRequirements: GNU make` only if Stage 1
  turns out to need it (decide there, not here). `Suggests: testthat,
  stringr`, stringr being the parity oracle of §9; add `nc` only when a test
  or article uses it.
- `.github/workflows/R-CMD-check.yaml`: add the `{"os": "windows-latest",
  "r": "devel"}` row to `runners`, keeping the four default rows. It runs in
  the full profile only and is the check win-builder would have given.
- `.github/workflows/coverage.yaml`: pin `coverage.yml` to a commit with the
  `v1` tag in a comment, since it holds a write token (template rule).
- `README.Rmd` replacing `README.md`, with the three-line pitch of design
  §1.3 and no examples yet; `NEWS.md` kept at "development version".
- Already done, not repeated: `CLAUDE.md` from the template, `.agents/`,
  `.Rbuildignore` entries, `pkgdown.yaml`, the MIT licence files.

**Exit criteria.**

- `R CMD check` passes on the quick r-actions profile with 0 errors, 0
  warnings and 0 notes other than "New submission".
- Every check on the stage's pull request finished in under five minutes.
  If not, `quick-step` or `quick-containers` was tuned in this pull request
  and the tuning is recorded here.
- `coverage.yaml` is pinned to a commit; `R-CMD-check.yaml` has the Windows
  R-devel row.
- `DESCRIPTION` has no placeholder text.

**Design.** §1.3, §2.

**Deviations (2026-10-21).**

- The README pitch keeps only what v0.1.0 ships (§2): "files scanned
  without `readLines()`", the lexer and callouts are left out until they
  land, so the README promises nothing the package does not do.
- `src/zuregex.c` gained `R_init_zuregex()` registering an empty routine
  table. Without it every CI leg raised the compiled-code NOTE about
  `R_registerRoutines` and `R_useDynamicSymbols`, against this stage's
  0-notes criterion.
- `coverage.yaml` sends the badge to `gh-pages` and `pkgdown.yaml` stops
  force-pushing. The ruleset on `main` rejected every badge commit, so
  coverage was red on each push to `main`.

## Stage 1 — Vendor PCRE2

**Issue.** [#3](https://github.com/pedrobtz/zuregex/issues/3), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuregex/issues/1).

**CI.** `full — first compiled code and a vendored library: sanitizers,
valgrind, rchk and every platform leg have to pass on the build every later
stage compiles against.`

**Goal.** PCRE2 10.48, 8-bit with JIT, builds inside the package on every
r-actions leg without `cmake`, with hidden symbols, and `zuregex_info()`
reports what was built.

**Work.**

- `src/vendor/pcre2/`: the 8-bit sources and headers from the 10.48 release
  tarball, with the JIT compiler and its `sljit` sources, and nothing else
  (no 16-bit or 32-bit, no POSIX wrapper, no `pcre2grep`, no `pcre2test`).
  Upstream `LICENCE.md` and `AUTHORS.md` kept beside them.
- A hand-written `config.h` and `pcre2.h` (generated once from the
  `.generic` files) instead of `cmake` or `configure`.
- `src/Makevars` with an `OBJECTS` list, `PKG_CFLAGS = $(C_VISIBILITY)`
  (family rule R3) and `PCRE2_CODE_UNIT_WIDTH=8`; `src/Makevars.win` if the
  Windows legs need one. `vectorscan`'s build is the starting point.
- `tools/vendor/manifest.tsv`, `tools/vendor/checksums.sha256`,
  `tools/vendor/verify` and `src/vendor/PROVENANCE`, in the shape `zuhtml`
  uses. Patches under `tools/patches/` for every `stdio`, `abort` or `exit`
  symbol the CRAN compiled-code check would flag, listed in `PROVENANCE`.
- `inst/COPYRIGHTS` and the `cph` entry for the PCRE2 authors in
  `DESCRIPTION`; `Copyright:` field pointing at `inst/COPYRIGHTS`.
- `zuregex_info()`: the vendored PCRE2 version, whether JIT compiled and
  whether it is usable at run time (JIT failure is silent, design §4),
  Unicode support. OpenMP fields arrive in Stage 8.
- `.github/workflows/native-checks.yaml` and `vendor.yaml` from the
  r-actions examples. `vendor.yaml` runs `tools/vendor/verify` and guards
  `src/vendor/` against unrecorded edits.
- A CI step running `nm -u` on the built objects that fails on `printf`,
  `abort`, `exit`, `stdout`, `stderr` and the system RNG.

**Exit criteria.**

- The package builds and `R CMD check` is clean on the full r-actions
  profile: runners, containers, sanitizers, valgrind, rchk, gctorture at
  the sensitive step, LTO.
- `zuregex_info()$pcre2_version` is `"10.48"` on every leg, and
  `zuregex_info()$jit` is `TRUE` on at least the Linux and Windows legs.
- The shared object exports `R_init_zuregex` only (checked with `nm` in
  CI).
- `tools/vendor/verify` passes and reproduces the tree from the manifest
  plus exactly the recorded patches.
- The built source tarball is under 5 MB (design §12). The installed size
  is recorded in this roadmap's open questions, with whether it draws the
  installed-size NOTE.
- Decision D1 is ratified: the engine is vendored PCRE2 at 10.48. Record it
  as **(M)** in `design.md` §13 when this stage merges.

**Design.** §4 (hidden symbols, JIT failure), §11 stage 0, §13 D1.

## Stage 2 — Compile, flags and the cache

**Issue.** [#4](https://github.com/pedrobtz/zuregex/issues/4), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuregex/issues/1).

**CI.** `full — the \`re\` external pointer, its finalizer and the cache's
ownership of \`pcre2_code\` are the memory model every verb builds on;
gctorture at step 20, valgrind and ASan check what the quick profile cannot.`

**Goal.** A pattern can be compiled, inspected and cached from R. Nothing
matches yet.

**Work.**

- `re_compile(pattern, flags, dialect, literal, jit)`, vectorised, returning
  an `re` object: external pointers to `pcre2_code`, JIT compiled when the
  platform allows, with finalizers; `print()` and `format()` methods.
- The `flags` letters of §5.1 mapped to PCRE2 compile and extra options;
  unknown letters are a `zuregex_error_flags`.
- `dialect = "pcre"` (base R's `perl = TRUE` option set) and `"js"`
  (node-pcre2's set) as in §6.3, as option sets only; the empty-match
  advance rule for `"js"` lands with `re_locate_all()` in Stage 4.
- `re_info(re)`: group count and names, flags, dialect, JIT in use, minimum
  subject length, literal prefix, back-references, PCRE2 version.
- `re_escape(x)`.
- The LRU cache of §6.4 and D4: keyed by pattern, flags, dialect and
  `literal`; 128 entries by default, 256 at most, nothing over 65,536
  characters; `re_cache_size()` and `re_cache_clear()`. Main thread only.
- The condition hierarchy root `zuregex_error` and `zuregex_error_compile`
  with pattern, offset and PCRE2's message, printed with a caret under the
  offending position.

**Exit criteria.**

- `re_compile()` round-trips every flag letter of §5.1 into the option
  `re_info()` reports; every invalid pattern raises
  `zuregex_error_compile` with the right offset.
- Cache tests: hits, evictions at capacity, over-length patterns bypass,
  `re_cache_clear()` empties, and cached and uncached objects report the
  same `re_info()`.
- Compiling the same pattern 10,000 times costs under 5% of the first
  compile, measured in a test that is skipped on CRAN.
- Full profile green, including gctorture at the sensitive step and
  valgrind with no definite or indirect leaks from `re` objects collected
  in a loop.

**Design.** §5.1, §6.3, §6.4, §8, §13 D2 to D4.

## Stage 3 — Detect and count

**Issue.** [#5](https://github.com/pedrobtz/zuregex/issues/5), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuregex/issues/1).

**CI.** `quick`.

**Goal.** The first verbs run, serially, through the three-phase structure
that Stage 8 parallelises, and they agree with base R.

**Work.**

- The pairing rule of §6.5 and D8: `pattern` of length one or exactly
  `length(x)`, anything else `zuregex_error_length`; distinct patterns
  compiled once, through the cache when they fit, into a per-call table
  when they do not; `NA` pattern gives `NA`.
- The three phases of §4 as the shape of every verb: collect subject
  pointers and translate encodings on the main thread; a match loop that
  never touches the R API; build results in input order. Serial for now,
  written so that Stage 8 adds the OpenMP pragma and nothing else.
- Strings and bytes (§6.1): character input matched as UTF-8, other
  declared encodings translated, raw vectors and `useBytes` strings matched
  without `PCRE2_UTF`, invalid UTF-8 a `zuregex_error_utf` with element and
  byte.
- `re_detect(x, pattern, anchor, negate)` with `anchor` done through
  `PCRE2_ANCHORED` and `PCRE2_ENDANCHORED`, and `re_count(x, pattern)`.
- Parity tests against `grepl(perl = TRUE)` and `stringr::str_detect()` /
  `str_count()` on a shared corpus, with every deliberate difference a
  named test marked `# GAP`.

**Exit criteria.**

- `re_detect()` equals `grepl(perl = TRUE)` on the parity corpus, with
  every difference marked `# GAP` and explained.
- Pattern lengths: one and `length(x)` work, every other length including
  divisors errors with `zuregex_error_length`, and per-element results
  equal a loop over single-pattern calls.
- A raw vector and the same bytes as a UTF-8 string give the same
  `re_detect()` result for ASCII patterns; invalid UTF-8 in character input
  raises `zuregex_error_utf` naming the element.
- Quick profile green; `devtools::test(shuffle = TRUE)` green.

**Design.** §4, §5.2 (detect, count), §6.1, §6.3, §6.5, §13 D8.

## Stage 4 — Locate

**Issue.** [#6](https://github.com/pedrobtz/zuregex/issues/6), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuregex/issues/1).

**CI.** `quick`.

**Goal.** Matches can be located, in characters or bytes, one or all, and
the offset convention is fixed.

**Work.**

- `re_locate(x, pattern, bytes)`: a two-column integer matrix, one-based,
  inclusive, in characters; `bytes = TRUE` for byte offsets; `NA` for no
  match; an empty match at `k` is `start = k, end = k - 1` (§6.2, D6).
- `re_locate_all(x, pattern, n, overlap, bytes)`: a data frame with
  `element`, `match`, `start`, `end`; PCRE2's empty-match advance rule for
  `dialect = "pcre"` and JavaScript's for `"js"`.
- The character-offset computation for UTF-8 subjects, done in phase 2
  with no R API, so that Stage 8 can parallelise it.
- Parity tests against `regexpr()`, `gregexpr()` and
  `stringr::str_locate()` / `str_locate_all()`.

**Exit criteria.**

- `substr(x, start, end)` on `re_locate()`'s output extracts the match for
  every element of the parity corpus, including non-ASCII subjects; the
  same with `x[start:end]` for raw input.
- `re_locate_all()` matches `gregexpr(perl = TRUE)` on the corpus apart
  from `# GAP` tests, and `n` and `overlap` are tested at their edges (0,
  1, `Inf`; overlapping matches of `"aa"` in `"aaaa"`).
- Quick profile green.

**Design.** §5.2 (locate), §6.2, §6.3, §13 D6.

## Stage 5 — Extract and match

**Issue.** [#7](https://github.com/pedrobtz/zuregex/issues/7), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuregex/issues/1).

**CI.** `quick`.

**Goal.** Captures come back as vectors and data frames filled in C, which
is the package's main speed claim for R users.

**Work.**

- `re_extract(x, pattern, group)` and `re_extract_all(x, pattern, group,
  n)`, with `group` by number or name.
- `re_match(x, pattern, proto)`: one row per element, one column per group,
  named or numbered, `NA` rows for no match, typed through `proto` as
  `utils::strcapture()` does.
- `re_match_all(x, pattern, n)`: one row per match, with `element` and
  `match` columns.
- Group union across differing per-element patterns (§6.5): same-named
  groups share a column, unnamed groups share by position, missing groups
  are `NA`.
- The one place a CHARSXP is made from an offset pair, shared by every
  extracting verb, so encoding marking is decided once.
- Parity tests against `regmatches()`, `utils::strcapture()` and
  `stringr::str_match()` / `str_match_all()`; a benchmark against
  `strcapture()`, skipped on CRAN.

**Exit criteria.**

- `re_match()` equals `strcapture()` on the corpus for typed captures, and
  `str_match()` for untyped, apart from `# GAP` tests.
- Differing patterns across elements produce the documented column union,
  tested with named, numbered and missing groups.
- `re_match()` is at least 10× faster than `utils::strcapture()` on a
  100,000-element corpus, one thread, in the skipped-on-CRAN benchmark
  (design §10; `hs_capture()` measured 21×). Record the number here.
- Quick profile green.

**Design.** §5.3, §6.5, §10.

## Stage 6 — Replace, expand and split

**Issue.** [#8](https://github.com/pedrobtz/zuregex/issues/8), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuregex/issues/1).

**CI.** `quick`.

**Goal.** The remaining verbs of v0.1.0, with PCRE2's extended substitution
language as the template syntax.

**Work.**

- `re_replace(x, pattern, replacement, n, syntax)` with `syntax =
  "extended"` (D7: `$1`, `${name}`, `${1:-d}`, `${1:+a:b}`, case forcing,
  `$$`) and `"literal"`, through `pcre2_substitute()` with its
  overflow-and-retry buffer protocol.
- `replacement` as a function: called once with a data frame of every
  match and its groups, returning one string per row.
- `re_expand(x, pattern, template)`.
- `re_split(x, pattern, n, keep_groups)`, as Python's `re.split()` and
  Go's `Split(n)`.
- Template errors as `zuregex_error_template`, a `zuregex_error` with the
  offending position.
- Parity tests against `sub()`, `gsub()`, `strsplit()` and
  `stringr::str_replace()` / `str_replace_all()` / `str_split()`, with
  `# GAP` tests for the template syntax difference.

**Exit criteria.**

- Every template form in the §5.4 table has a test; a malformed template
  raises `zuregex_error_template`.
- `re_replace()` with a function receives exactly the data frame §5.4
  describes and is called once per call, not once per match.
- `re_split(keep_groups = TRUE)` interleaves groups between pieces as
  Python does, tested against recorded Python output.
- Quick profile green.

**Design.** §5.4, §13 D7.

## Stage 7 — Limits

**Issue.** [#9](https://github.com/pedrobtz/zuregex/issues/9), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuregex/issues/1).

**CI.** `quick`.

**Goal.** Every matching verb bounds its work per element, and hitting a
limit is a classed error or an `NA` the caller asked for.

**Work.**

- `re_limits(match, depth, heap, on_limit)` and a `limits =` argument on
  every verb of Stages 3 to 6, defaulting to `getOption("zuregex.limits")`
  and then to PCRE2's defaults (D11).
- A match context per call carrying the limits; one per thread from Stage
  8 on.
- `zuregex_error_limit` naming the limit and the element; `on_limit =
  "na"` gives `NA` for that element and one warning summarising how many
  did.
- Documentation of §6.7 in the package: no linear-time promise, `re2` for
  that.

**Exit criteria.**

- A pathological pattern on a long subject stops within the match limit on
  every verb, raising `zuregex_error_limit`, and gives `NA` plus one
  warning with `on_limit = "na"`.
- Limits set through the option and through the argument behave the same;
  the argument wins when both are set.
- Quick profile green.

**Design.** §5.5, §6.7, §8, §13 D11.

## Stage 8 — OpenMP

**Issue.** [#10](https://github.com/pedrobtz/zuregex/issues/10), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuregex/issues/1).

**CI.** `full — the parallel match loop is what the sanitizers, valgrind
and every platform leg exist for; a race here corrupts results silently.`

**Goal.** Phase 2 of every verb runs on several threads, results are
identical for any thread count, and the package is correct where OpenMP is
absent.

**Work.**

- `configure` and `configure.win` as `zurand` has them (D5): the probe that
  links R's own `libomp` on macOS, the `_OPENMP` and `<omp.h>` guard, and a
  serial build where the probe fails.
- One match-data block, match context and JIT stack per thread; the
  compiled-pattern table shared read-only; dynamic scheduling for
  per-element patterns.
- `re_threads(n)` with `rng_threads()`'s contract: `NULL` queries, a number
  caps, `0` removes the cap, setting returns the previous value.
- A serial threshold in total subject bytes, measured and recorded here.
- `tests/testthat/setup.R` capping the suite at two threads;
  `zuregex_info()` gaining `openmp`, `threads` and `cache_size`.
- Thread-invariance tests: every verb of Stages 3 to 7, with one pattern
  and with one pattern per element, above the threshold, at one thread and
  at the cap.

**Exit criteria.**

- Every verb gives identical results at one thread and at two or more
  on inputs above the threshold; the test suite runs with the cap at two.
- The serial build (OpenMP absent) passes the whole suite; CI has at least
  one leg without OpenMP, or the test forces it by setting the cap to one.
- `re_detect()` with four threads is at least 2.5× faster than one on a
  non-memory-bound pattern, in a benchmark skipped on CRAN (design §10).
  Record the number here.
- Full profile green: ASan and UBSan, valgrind, gctorture at the sensitive
  step, every runner including Windows R-devel and macOS with R's `libomp`.

**Design.** §4, §5.6, §6.6, §10, §13 D5.

## Stage 9 — C API and consumers

**Issue.** [#11](https://github.com/pedrobtz/zuregex/issues/11), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuregex/issues/1).

**CI.** `quick`.

**Goal.** Other packages reach PCRE2 through `LinkingTo: zuregex`, a
consumer proves it in CI, and PCRE2's own test corpus runs through that API.

**Work.**

- `inst/include/zuregex.h` with the opaque `zr_pattern` and
  `zr_match_data` handles and the functions of §7 (`zr_compile`,
  `zr_match`, `zr_substitute`, `zr_free`, `zr_version`, plus match data,
  group lookup by name and limits), registered with `R_RegisterCCallable()`
  and found by consumers through `R_GetCCallable()`. Zero-based, half-open
  byte offsets.
- A consumer fixture under `tools/consumer/` and a `consumer.yaml`
  workflow that installs it with `zuregex` removed from the library path
  (family rule R10.4).
- `tools/revdep/consumers.txt` with `pedrobtz/vectorscan` and the branch
  of the next item, and `revdep.yaml` from the r-actions example.
- `vectorscan` switched to `LinkingTo: zuregex` on a branch in its
  repository, its vendored PCRE2 removed, its tests passing. The branch is
  not merged here (D9; that is `vectorscan`'s pull request).
- The PCRE2 `testdata/` conformance subset: pattern and subject pairs from
  the main test inputs, run through the C API from a test harness, with the
  skipped cases listed and the reason for each.
- A `zufuzz` harness for `zr_compile` and `zr_match` and `fuzz.yaml` from
  the r-actions example.

**Exit criteria.**

- The consumer fixture compiles and runs against the installed package
  with `zuregex` absent from `.libPaths()` in `consumer.yaml`.
- `vectorscan`'s branch builds against this package's checkout in
  `revdep.yaml` and its test suite passes.
- The PCRE2 `testdata/` subset passes through the C API; every skipped
  case is listed with its reason.
- `zuregex.h` compiles standalone as C99 with `-Wall -Wextra -pedantic`.
- The fuzz harness runs for its CI budget with no finding.
- Quick profile green.

**Design.** §3, §7, §9, §12, §13 D9, D10.

## Stage 10 — Full CI

**Issue.** [#12](https://github.com/pedrobtz/zuregex/issues/12), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuregex/issues/1).

**CI.** `full — always.`

**Goal.** No new features. The full r-actions profile runs on the default
branch's code and everything it finds is fixed.

**Work.**

- Run the full profile with the `full-ci` label: gctorture at step 20,
  valgrind, ASan and UBSan, every runner and container, `nosuggests`,
  `nold`, cran-special, rchk, LTO, analyzers.
- Fix every finding here, including the ones earlier `quick` stages
  parked on this issue as comments.
- Run `urlchecker::url_check()` and `spelling::spell_check_package()` once
  so Stage 11 starts clean.

**Exit criteria.**

- A full-profile run is green on the pull request and on its merge commit.
- `native-checks.yaml`, `vendor.yaml`, `consumer.yaml`, `revdep.yaml` and
  `fuzz.yaml` are green on the merge commit.
- No open comment on this issue describes an unfixed full-profile finding.

**Design.** §12.

## Stage 11 — v0.1.0 readiness

**Issue.** [#13](https://github.com/pedrobtz/zuregex/issues/13), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuregex/issues/1).

**CI.** `full — always.`

**Goal.** Only the submission itself is left.

**Work.**

- `Version: 0.1.0` in `DESCRIPTION` and the matching `NEWS.md` heading
  listing the verbs, the cache, OpenMP, limits and the C API.
- `cran-comments.md` listing the r-actions CI legs as test environments.
- `pkg-critical-review` run; blocking and required findings fixed.
- `pkg-cran-review` run; every finding resolved.
- `README.Rmd` with the pitch and one example per verb group (`pkg-readme`),
  and a pkgdown reference index grouped as §5 groups the API.
- Lifecycle badges on anything incubating, per the open question below.

**Exit criteria.**

- `devtools::check()` clean with only the "New submission" note.
- `urlchecker::url_check()` and `spelling::spell_check_package()` clean.
- Both review skills run and their findings closed.
- A full-profile r-actions run is green on the release commit.
- The source tarball is under 5 MB.

**Design.** §12.

## After 0.1.0

In the order design §14 expects them:

- **Files and connections** (`re_scan_file()`, `re_scan_conn()`), with
  partial matching across chunk boundaries. Deferred because it needs
  `PCRE2_PARTIAL_HARD` and chunked I/O that no v0.1.0 verb shares; see the
  open question on whether it should move in.
- **The lexer** `re_lex()`, with `(*MARK:name)` tagging. Depends on the
  verbs and on `zupeg`'s needs being known.
- **R callouts** (§5.7, D10). Single-threaded by design; the API shape is
  recorded in the design so v0.1.0 does not close it off.
- **Serialized patterns** through `pcre2_serialize`, so `re` objects
  survive `saveRDS()`.
- **Pattern sets**, with `vectorscan` as the accelerator.
- **DFA matching**.
- **`syntax = "base"`** for `re_replace()`, if the open question below
  resolves that way.

## Open questions

- **File scanning in v0.1.0?** (design §15). This roadmap defers it, per
  the design's §2 scope. Decide before Stage 3 merges, since bringing it
  in changes the phase-1 subject collection.
- **`syntax = "base"` templates in `re_replace()`** (design §15). Blocks
  nothing in Stage 6, which ships `"extended"` and `"literal"`; a decision
  before Stage 6 avoids a later argument change.
- **Installed size with JIT** (design §15). Stage 1 measures it and records
  whether R CMD check raises the installed-size NOTE; if it does, fixing it
  (dropping JIT on some legs, or trimming tables) is Stage 1 work.
- **Marking incubating functions** (design §15). Lifecycle badges, as the
  family does, unless something in v0.1.0 is actually experimental. Decide
  in Stage 11.
- **D1 is still (C).** Stage 1 ratifies it or stops the roadmap.
- **`dialect = "js"` sufficiency for `zuschema`** (design §15). Not a
  v0.1.0 question; `zuschema`'s RFC decides whether it needs a translation
  layer on top.

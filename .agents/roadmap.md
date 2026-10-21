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
| 0 | [Package identity](#stage-0--package-identity) | quick | [#2](https://github.com/pedrobtz/zuregex/issues/2) | [#16](https://github.com/pedrobtz/zuregex/pull/16) | 2026-10-21 |
| 1 | [Vendor PCRE2](#stage-1--vendor-pcre2) | full | [#3](https://github.com/pedrobtz/zuregex/issues/3) | [#17](https://github.com/pedrobtz/zuregex/pull/17) | 2026-10-21 |
| 2 | [Compile, flags and the cache](#stage-2--compile-flags-and-the-cache) | full | [#4](https://github.com/pedrobtz/zuregex/issues/4) | [#18](https://github.com/pedrobtz/zuregex/pull/18) | 2026-10-21 |
| 3 | [Detect and count](#stage-3--detect-and-count) | quick | [#5](https://github.com/pedrobtz/zuregex/issues/5) | [#19](https://github.com/pedrobtz/zuregex/pull/19) | 2026-10-21 |
| 4 | [Locate](#stage-4--locate) | quick | [#6](https://github.com/pedrobtz/zuregex/issues/6) | [#20](https://github.com/pedrobtz/zuregex/pull/20) | 2026-10-21 |
| 5 | [Extract and match](#stage-5--extract-and-match) | quick | [#7](https://github.com/pedrobtz/zuregex/issues/7) | [#21](https://github.com/pedrobtz/zuregex/pull/21) | 2026-10-21 |
| 6 | [Replace, expand and split](#stage-6--replace-expand-and-split) | quick | [#8](https://github.com/pedrobtz/zuregex/issues/8) | [#22](https://github.com/pedrobtz/zuregex/pull/22) | 2026-10-21 |
| 7 | [Limits](#stage-7--limits) | quick | [#9](https://github.com/pedrobtz/zuregex/issues/9) | [#23](https://github.com/pedrobtz/zuregex/pull/23) | 2026-10-21 |
| 8 | [OpenMP](#stage-8--openmp) | full | [#10](https://github.com/pedrobtz/zuregex/issues/10) | [#24](https://github.com/pedrobtz/zuregex/pull/24) | 2026-10-21 |
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

**Deviations (2026-10-21).**

- The `nm` gate is `tests/testthat/test-abi.R`, run by R CMD check on
  every CI leg, rather than a separate workflow step. It fails on any
  exported symbol but `R_init_zuregex` and on any linked stdio, exit,
  abort or RNG symbol. Windows is skipped, as in zucrypt: a DLL exports
  only its export table, and modules cannot bind to each other's copies.
- No stdio, abort or exit patch was needed: PCRE2 10.48's library links
  none. One patch was: `0001-split-compile-error-texts.patch` splits a
  5,686-character string literal, because clang `-pedantic` warns that it
  exceeds ISO C99's 4,095 and R CMD check reports that warning.
- The keep list is `tools/vendor/keep/pcre2.txt`, and
  `vendor-upstream.yaml` watches PCRE2 releases weekly. Neither was named
  in the work list.
- The vendored tree keeps upstream's `src/` and `deps/sljit/` layout, since
  `pcre2_jit_compile.c` includes `../deps/sljit/sljit_src/sljitLir.c`. The
  longest tarball path is 90 bytes, under the 100-byte limit.

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

**Deviations (2026-10-21).**

- PCRE2 is built with `LINK_SIZE 4`, not upstream's 2. With 2, a pattern
  of 65,537 characters, which the cache must compile and skip, fails with
  "regular expression is too large".
- `literal = TRUE` accepts only the flags `i` and `r`, the ones
  `PCRE2_LITERAL` allows; any other is a `zuregex_error_flags`. The
  dialect's options are dropped for a literal instead.
- A compile error's `offset` is where PCRE2 detected the error, as a
  one-based character position. That is usually just after the offending
  item, and the caret points there.
- `re` objects survive `saveRDS()`: an element whose pointer did not
  survive is recompiled from the object's attributes. The roadmap did not
  ask for this; it costs one check per call.
- The cache key also includes `jit`, so `re_info()$jit` is right for
  `jit = FALSE`.

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

**Deviations (2026-10-21).**

- `re_count()` steps past empty matches with `pcre2_next_match()`, PCRE2's
  own rule, for both dialects. JavaScript's rule arrives with
  `re_locate_all()` in Stage 4, which will switch `re_count()` to it for
  `dialect = "js"`.
- A raw vector is one subject, and a list of raw vectors is one subject
  per element, with `NULL` for `NA`. A character vector with any element
  marked `"bytes"` is matched as bytes throughout.
- Match-time anchoring makes PCRE2 use its interpreter instead of JIT
  code. That is correct but slower; compiling anchored variants is left
  for when a benchmark asks for it.
- Parity GAPs, each a named test: an `NA` subject gives `NA`, where
  `grepl()` gives `FALSE`; `re_count()` counts the empty match after a
  non-empty one, as Python does, where `gregexpr()` does not; `\w`, `\d`
  and POSIX classes are ASCII as in base R, where stringr's ICU is
  Unicode.

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

**Deviations (2026-10-21).**

- `re_count()` now uses the same iteration as `re_locate_all()`, so
  `dialect = "js"` counts with JavaScript's empty-match rule, as Stage 3
  recorded it would.
- `re_locate_all()` gives an `NA` subject or pattern one row of `NA`, and a
  subject with no match no rows. stringr gives a one-row `NA` matrix for
  both cases.
- Subjects over 2^31 - 1 bytes are refused, since offsets are R integers.
- Parity GAPs, each a named test: stringr reports an empty match at 1 as
  `start = 1, end = 1` and none in `""`; `gregexpr()` drops the empty match
  after a non-empty one, which PCRE2 and stringr both report.

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

**Measured (2026-10-21).** `re_match()` with a three-column `proto` on
100,000 strings: 0.111 s against `utils::strcapture()`'s 1.931 s, 17.4×
(median of three, one thread, macOS x86-64). The test asserts 10× where
`ZUREGEX_TIMING_TESTS=true`.

**Deviations (2026-10-21).**

- `re_match()` has no column for the whole match: its columns are the
  groups, as in Python's `groups()`. `re_extract()` gives the whole match.
- An unnamed group's column is named by its number (`"1"`, `"2"`).
- `proto` columns with S4 classes are refused, since converting them needs
  the `methods` package and the package has no Imports.
- `group` naming a group no pattern has, or a number past every pattern's
  groups, is a new `zuregex_error_group`.
- Parity GAP, a named test: `regmatches()` and `strcapture()` give `""` for
  a group that did not take part in the match; zuregex and stringr give
  `NA`.

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

**Deviations (2026-10-21).**

- A malformed template is reported when a match first uses it, since
  PCRE2 checks a template only while substituting. A template no match
  uses is never checked.
- The replacement function is called at most once: not at all when
  nothing matched. Its data frame names the whole match `0`, next to the
  group columns `re_match()` uses.
- A group that did not take part is replaced by `""`
  (`PCRE2_SUBSTITUTE_UNSET_EMPTY`); a group that does not exist is a
  template error.
- `re_split(n = 0)` gives no pieces, as Go's `Split(0)` does.
- Python's results are recorded by `tools/oracles/python-re.py` and
  checked as literals in `test-python.R`, so the tests need no Python.
- Parity GAPs, each a named test: `gsub()` skips an empty match right
  after a non-empty one, where Python and PCRE2 replace it; `strsplit()`
  drops a trailing empty piece; base R's `\\1` templates are written `$1`,
  though PCRE2 also reads `\\1`.

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

**Deviations (2026-10-21).**

- `heap` is in kibibytes, PCRE2's unit. The JIT compiler honours only
  `match`; `depth` and `heap` bound the interpreter, as PCRE2 documents.
  A JIT stack overflow is reported as the `jit_stack` limit.
- The warning has class `zuregex_warning_limit` and a `count` field.
- With `on_limit = "na"`, an element that hits a limit after some matches
  gives `NA`, not the matches found before the limit.

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

**Measured (2026-10-21)**, in a Linux container (rocker/r-ver 4.5.1, gcc,
four CPUs of a 2019 x86-64 laptop), median of three runs:

| Measure | 1 thread | 4 threads | Ratio |
| --- | --- | --- | --- |
| `re_detect()`, `(\\w+)\\s(\\w+)\\s\\2\\1`, 200,000 × 120 characters | 1.038 s | 0.313 s | 3.32× |
| `re_detect()`, `\\b(\\w)\\w*\\1\\b`, same input | 0.331 s | 0.115 s | 2.88× |
| `re_detect()`, `[0-9]`, 8 KiB per call | 41.7 µs | 44.9 µs | 0.93× |
| `re_detect()`, `[0-9]`, 16 KiB per call | 57.7 µs | 51.3 µs | 1.12× |
| `re_detect()`, `[0-9]`, 64 KiB per call | 153.8 µs | 76.9 µs | 2.00× |

The serial threshold is 16 KiB of total subject bytes, where four threads
first beat one on the cheapest pattern. The test asserts 2.5× for the first
pattern where `ZUREGEX_TIMING_TESTS=true` and four threads are available.

**Deviations (2026-10-21).**

- No `configure.win` probe: `configure.win` writes `src/Makevars.win` from
  the same `src/Makevars.in` with R's own `$(SHLIB_OPENMP_CFLAGS)`, so one
  file holds the object list and defines. `tools/vendor/verify` now reads
  the template.
- An internal `serial_bytes()` sets the threshold, so the tests run the
  parallel path on small inputs too.
- The speedup test runs only with four physical cores. GitHub's four-vCPU
  Ubuntu runners have two, and four threads measured 1.99× one there
  (run 39678103610); the 3.32× above is from four cores.
- Phase 2 matches a copy of each subject followed by 64 zero bytes. PCRE2's
  JIT code reads past the end of the subject with wide loads, and past an R
  string valgrind saw those bytes as uninitialised (run 39678103829). The
  bug dates from Stage 3; only the full profile runs valgrind.
- The serial build is covered by legs without OpenMP: this package's local
  macOS build and the clang sanitizer containers, which define `_OPENMP`
  without `<omp.h>`.

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

- **File scanning in v0.1.0?** (design §15). Kept deferred at Stage 3
  (2026-10-21), as the design's §2 scope and this roadmap have it. Phase 1
  collects subjects through `zuregex_collect()` into pointer and length
  pairs, so a file or connection source can be added later without
  changing phases 2 and 3. The maintainer may still move it in; that
  would be a new stage.
- **`syntax = "base"` templates in `re_replace()`** (design §15). Stage 6
  (2026-10-21) ships `"extended"` and `"literal"` only. Adding `"base"`
  later is a new choice for the existing `syntax` argument, not an
  argument change. PCRE2's extended syntax already reads `\\1` to `\\9`,
  which covers most `gsub()` templates.
- **Installed size with JIT** (design §15). Settled by Stage 1
  (2026-10-21): no leg raises the installed-size NOTE ("checking installed
  package size ... OK" on Ubuntu release and oldrel, macOS, both Windows
  legs and clang23). The source tarball is 0.8 MB and the installed
  package 0.9 MB on macOS.
- **Marking incubating functions** (design §15). Lifecycle badges, as the
  family does, unless something in v0.1.0 is actually experimental. Decide
  in Stage 11.
- **D1** was ratified by Stage 1 (2026-10-21) and is now **(M)** in the
  design.
- **`dialect = "js"` sufficiency for `zuschema`** (design §15). Not a
  v0.1.0 question; `zuschema`'s RFC decides whether it needs a translation
  layer on top.

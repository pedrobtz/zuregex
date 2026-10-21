# RFC 0042: `zuregex`, PCRE2 for R code and for C code

Adopted from [RFC 0042](https://github.com/pedrobtz/packages/blob/main/rfcs/started/0042-zuregex-pcre2-for-r-and-c.md)
on 2026-10-21. From here on this file is authoritative; the RFC is history.

- **Status:** Proposed. A compilation of the ideas from the 21 October
  2026 brainstorm, in RFC form so that it can be reviewed and promoted.
  The maintainer decided every decision in section 13 the same day
  except D1, which is still **(C)**.
- **Date:** 2026-10-21.
- **Packages:** `zuregex` (not yet created; the name was absent from
  crandb and from the `pedrobtz` account on 2026-10-21). No `Imports`.
  `Suggests: testthat, stringr, nc`. Vendors the PCRE2 8-bit library with
  its JIT compiler (BSD-3-Clause with the PCRE2 binary-library
  exception). MIT for its own code, with the vendored licence in
  `inst/COPYRIGHTS`.
- **Source:** the PCRE2 10.48 documentation (`pcre2api`, `pcre2pattern`,
  `pcre2partial`, `pcre2callout`, `pcre2jit`, `pcre2serialize`); the
  README of `@segevfiner/pcre2` 0.1.3 on npm (repository
  `segevfiner/node-pcre2`); the README of `grtetrault/pcre2.py` (PyPI
  `pcre2`); the README and `pcre/cache.py` of `ModelCloud/PyPcre` 0.6.5
  for its pattern cache; the README and `experimental` package of
  `wasilibs/go-re2`
  (the brainstorm named `wasilibs/go-pcre`, which does not exist; go-re2
  is wasilibs' regex package and stands in for the Go side); Go's
  `regexp` package documentation; `pedrobtz/vectorscan` at `main`
  (`R/capture.R`, `src/capture.c`, `roadmap.md`), which vendors PCRE2
  10.48 (2026-08-31); `zurand`'s `configure` and `src/zurand.c` for the
  OpenMP setup; the CRAN index of 2026-10-21 for `re2`, `nc`,
  `grepreaper`, `findInFiles` and `RcppCWB`; section 3.1 of
  [`base-layer-candidates.md`](https://github.com/pedrobtz/packages/blob/main/rfcs/base-layer-candidates.md), which this
  RFC replaces. Nothing has been built.

## 1. What zuregex is

`zuregex` is PCRE2 packaged twice: as an R package whose functions do
things base R's `perl = TRUE` engine cannot, and as a C library that other
packages link to instead of vendoring their own copy. The engine is the
one R already uses. The value is in everything around it.

### 1.1 What base R already does

Base R matches `perl = TRUE` patterns with PCRE2 and its JIT compiler.
`extSoftVersion()["PCRE"]` reports 10.47 on the CRAN macOS build used for
this RFC; on Linux R uses the system library, which is 10.42 on Debian 12
and Ubuntu 24.04. So the pattern syntax, JIT speed on one pattern over one
vector, and Unicode properties are not reasons for this package. A
package that only re-exposed them would be the same engine with a new
API.

What base R does not do:

<!-- markdownlint-disable MD013 -->

| Gap in base R | Consequence |
| --- | --- |
| No C access to PCRE2 for packages | Every package that needs PCRE2 in C vendors it; `vectorscan` does. No CRAN package offers it through `LinkingTo` (`RcppCWB` needs a system PCRE2) |
| One PCRE2 version per platform, chosen by the platform | Variable-length look-behind (10.43) is missing on current Debian and Ubuntu |
| Compiles the pattern on every call | Calls inside `lapply()`, `purrr::map()`, rowwise dplyr or Shiny recompile, and JIT-compile, the same pattern thousands of times |
| One thread | Matching a million strings uses one core |
| Replacement knows `\\1` to `\\9` and `\\U`, `\\L`, `\\E` only | No named references, no groups past nine, no defaults or conditionals |
| Captures arrive as attributes of `regexpr()` results | `regmatches()` does not extract groups; `utils::strcapture()` is slow |
| Every subject must be an R string | Scanning a file means `readLines()` first, and creating one R string per line is the main cost |
| No per-call match, depth or heap limit | A pathological pattern runs for a long time or errors |
| No callouts, no lexer, no partial matching | Each is out of reach from R code |

<!-- markdownlint-enable MD013 -->

### 1.2 What the inspirations contribute

Three bindings shaped the feature list. None is a template for the R API;
each contributes ideas that survive translation to R.

<!-- markdownlint-disable MD013 -->

| Idea | Source | Where it lands |
| --- | --- | --- |
| A compiled `Pattern` object with flags, `jit`, `groupindex` | pcre2.py | `re_compile()`, `re_info()` (§5.1) |
| `match` / `fullmatch` / `search` as anchoring modes | pcre2.py, Python `re` | `anchor =` argument (§5.2) |
| `sub` with `count`, `Match.expand()` | pcre2.py | `re_replace(n =)`, `re_expand()` (§5.4) |
| `finditer` over all non-overlapping matches | pcre2.py | `re_locate_all()`, `re_match_all()` (§5.3) |
| Callouts with pass / fail / abort returns | pcre2.py | `callout =` (§5.7) |
| Accepting bytes as well as strings | pcre2.py | raw vectors everywhere (§6.1) |
| JavaScript-compatible defaults with a switch to plain PCRE2 | node-pcre2 | `dialect = "js"`, opt-in (D2) |
| One-letter flags for the newer PCRE2 options (`xx`, `n`, `aD`/`aS`/`aW`/`aT`/`aP`, `r`, `J`, `U`) | node-pcre2 | the `flags` string (§5.1) |
| A tagged template for patterns | node-pcre2 | no R equivalent; dropped |
| A complete, systematic verb grid (`Find`, `FindAll`, `…Submatch`, `…Index`, `…String`) | Go `regexp` via go-re2 | the verb grid of §5 |
| `FindAll(n)`, `Split(n)`, `QuoteMeta`, `SubexpNames`, `LiteralPrefix` | Go `regexp` | `n =` arguments, `re_escape()`, `re_info()` |
| Documented "gaps" against the reference behaviour, marked in tests | go-re2 (`// GAP`) | parity tests against base R (§9) |
| `CompileLatin1`, matching non-UTF-8 input | go-re2 experimental | bytes mode (§6.1) |
| `Set`, many patterns searched together | go-re2 experimental | later, with `vectorscan` as the accelerator (§14) |
| An `experimental` namespace with no stability promise | go-re2 | lifecycle badges, not a namespace (§15) |
| Automatic caching of compiled patterns, 128 entries by default | PyPcre | the pattern cache (D4) |

<!-- markdownlint-enable MD013 -->

### 1.3 The pitch in three lines

1. **For package authors:** PCRE2 through `LinkingTo`, one version on
   every platform, with a JavaScript dialect.
2. **For speed:** a compiled-pattern cache, OpenMP matching, captures
   filled in C, and files scanned without `readLines()`.
3. **For what R never had:** a lexer, callouts, PCRE2's full replacement
   language and per-call limits.

## 2. Scope

**In v0.1.0:** compiling with flags and dialects; the pattern cache; the
detect, count, locate, extract, match, replace, split and escape verbs
over character and raw vectors; per-call limits; OpenMP; the C API and
its first consumer.

**Later (§14):** file and connection scanning with partial matching, the
lexer, R callouts, serialized patterns, pattern sets, DFA matching.

**Never:** a linear-time guarantee (PCRE2 backtracks; §6.7 says what the
limits do instead); a new pattern syntax; locale-dependent character
tables; the 16-bit and 32-bit PCRE2 libraries; `pcre2grep` and
`pcre2test` as shipped programs.

## 3. Position in the `zu*` family

`zuregex` is a provider, and section 2 of the candidates file's admission
test applies:

1. **Conformance corpus:** PCRE2's own `testdata/` and base R's
   `perl = TRUE` as a reference implementation.
2. **Vendorable:** BSD-3 C, no system dependency, and no `cmake` (the
   sources build from a hand-written `config.h`).
3. **Two or more siblings:** four.
4. **A real weakness in base R:** section 1.1.

<!-- markdownlint-disable MD013 -->

| Consumer | What it needs | Through |
| --- | --- | --- |
| `vectorscan` | The capture back-end of `hs_capture()`; drops its own PCRE2 copy | C API |
| `zutoken` (candidates §5.3) | GPT-style pre-tokenizer patterns, which use look-ahead | C API |
| `zuschema` (candidates §3.3) | JSON Schema's `pattern` and `patternProperties`, which are ECMA-262 patterns | C API, `dialect = "js"` |
| `zupeg` (RFC 0039) | A lexer front end, listed there as a later direction | `re_lex()` and C API |

<!-- markdownlint-enable MD013 -->

**`vectorscan` stays its own package.** It keeps Vectorscan, its
`hs_*` API and its multi-pattern routing, and gives up only its vendored
PCRE2 (D9). That removes about 5 MB of uncompressed source from it and
lets both packages share one PCRE2 version.

**Against the CRAN incumbents:** `re2` (linear time, RE2 syntax, R API
only), `nc` (named captures to data tables over base R's engines),
stringr and stringi (ICU, no C access, single-threaded), and
`grepreaper` and `findInFiles`, which shell out to `grep` and show that
file scanning has users.

## 4. Architecture

```text
R API (re_*)                                   C API (inst/include/zuregex.h)
   │                                                  │
   ├─ argument checks, recycling, NA handling         │
   ├─ pattern cache (LRU, main thread) ───────────────┤
   │                                                  │
   ├─ phase 1, main thread: collect subject pointers; │
   │  translate non-UTF-8 input                       │
   ├─ phase 2, OpenMP: pcre2_match / pcre2_substitute │
   │  into preallocated offset, count and buffer      │
   │  arrays (one match-data block and JIT stack per  │
   │  thread)                                         │
   └─ phase 3, main thread: build R strings and data  │
      frames from offsets, in input order             │
                                                      │
                vendored PCRE2 10.48, 8-bit, JIT, hidden symbols
```

- **The compiled pattern** is an external pointer to a `pcre2_code`, JIT
  compiled when the platform allows it, with a finalizer. It is
  read-only once built, so threads share it.
- **Phase 2 never touches the R API.** `STRING_ELT`, translation and
  allocation can all allocate or run R code, so they stay in phases 1
  and 3. This is the same split `zurand` uses.
- **Symbols are hidden.** R itself has a `libpcre2-8` loaded, so the
  vendored copy is compiled with hidden visibility and linked into the
  package's shared object, where calls bind locally (family rule R3).
  `vectorscan` already does this and its build is the starting point.
- **JIT failure is silent.** Hardened macOS runtimes and SELinux can
  refuse executable memory; the interpreter runs instead, and
  `re_info()` reports which one a pattern uses.

## 5. Public R API (v0.1.0 shape)

Every function takes `pattern` as a character vector, compiled through
the cache, or as an `re` object from `re_compile()`. Every function is
vectorised over `x`. `pattern` has either one element, used for all of
`x`, or exactly `length(x)` elements, one per element of `x`; any other
length is an error, never recycled (D8, §6.5). `replacement` and
`template` follow the same rule. `x` may be a character vector or a raw
vector (§6.1).

### 5.1 Compiling and inspecting

```r
re_compile(pattern, flags = "", dialect = c("pcre", "js"),
           literal = FALSE, jit = TRUE)   # vectorised: an `re` vector
re_info(re)          # groups, group names, flags, dialect, jit,
                     # minimum subject length, literal prefix,
                     # has back-references, PCRE2 version
re_escape(x)         # quote metacharacters (Go's QuoteMeta)
zuregex_info()       # vendored PCRE2 version, JIT support, OpenMP,
                     # threads, cache size (family rule R9)
```

`flags` is a string of letters, taken from node-pcre2 where PCRE2 has no
Perl letter:

<!-- markdownlint-disable MD013 -->

| Letter | PCRE2 option | Meaning |
| --- | --- | --- |
| `i` | `PCRE2_CASELESS` | Case-insensitive |
| `m` | `PCRE2_MULTILINE` | `^` and `$` at line boundaries |
| `s` | `PCRE2_DOTALL` | `.` matches newline |
| `x` / `xx` | `PCRE2_EXTENDED` / `PCRE2_EXTENDED_MORE` | Ignore whitespace and allow comments; `xx` also inside classes |
| `n` | `PCRE2_NO_AUTO_CAPTURE` | Only named groups capture |
| `U` | `PCRE2_UNGREEDY` | Quantifiers lazy by default |
| `J` | `PCRE2_DUPNAMES` | Duplicate group names allowed |
| `u` | `PCRE2_UCP` | Unicode-aware `\w`, `\d`, `\b` and POSIX classes |
| `r` | `PCRE2_EXTRA_CASELESS_RESTRICT` | No case equivalence across the ASCII boundary |
| `aD` `aS` `aW` `aT` `aP` / `a` | `PCRE2_EXTRA_ASCII_*` | Keep `\d`, `\s`, `\w`, digits or POSIX classes ASCII under `u`; `a` sets all |

<!-- markdownlint-enable MD013 -->

### 5.2 Detecting and locating

```r
re_detect(x, pattern, anchor = c("none", "start", "full"), negate = FALSE)
re_count(x, pattern)
re_locate(x, pattern, bytes = FALSE)        # first match: start, end
re_locate_all(x, pattern, n = Inf, overlap = FALSE, bytes = FALSE)
```

`anchor = "start"` and `"full"` are Python's `match()` and `fullmatch()`,
done with `PCRE2_ANCHORED` and `PCRE2_ENDANCHORED` instead of rewriting
the pattern, which breaks on top-level alternation. `re_locate()` returns
a two-column integer matrix like `stringr::str_locate()`;
`re_locate_all()` returns a data frame with `element`, `match`, `start`
and `end`.

### 5.3 Extracting and capturing

```r
re_extract(x, pattern, group = 0)
re_extract_all(x, pattern, group = 0, n = Inf)
re_match(x, pattern, proto = NULL)          # one row per element
re_match_all(x, pattern, n = Inf)           # one row per match
```

`re_match()` is `vectorscan::hs_capture()` for one pattern: a data frame
with one column per group, named or numbered, `NA` rows where nothing
matched, and typed columns when `proto` is given, as for
`utils::strcapture()`. `re_match_all()` adds `element` and `match`
columns. Both are filled in C, which is where `hs_capture()`'s measured
21× over `strcapture()` came from.

### 5.4 Replacing and splitting

```r
re_replace(x, pattern, replacement, n = Inf,
           syntax = c("extended", "literal"))
re_expand(x, pattern, template)             # Python's Match.expand()
re_split(x, pattern, n = Inf, keep_groups = FALSE)
```

`replacement` is a template in PCRE2's extended substitution syntax (D7):

<!-- markdownlint-disable MD013 -->

| Template | Meaning |
| --- | --- |
| `$1`, `${12}`, `${name}` | Group by number, past nine, or by name |
| `${1:-none}` | The group, or `none` when it did not participate |
| `${1:+yes:no}` | `yes` when the group participated, otherwise `no` |
| `\U…\E`, `\L…\E`, `\u`, `\l` | Case forcing |
| `$$` | A literal `$` |

<!-- markdownlint-enable MD013 -->

`replacement` may instead be a function. It is called once, not once per
match, with a data frame of all matches (`element`, `match`, the full
match and every group) and returns a character vector of that many rows.
stringr already calls its replacement function once with all matches; the
groups are what is new.

`re_split()` follows Python's `re.split()` and Go's `Split(n)`: at most
`n` pieces, and with `keep_groups = TRUE` the captured groups of each
separator are kept between the pieces.

### 5.5 Limits

```r
re_limits(match = NULL, depth = NULL, heap = NULL,
          on_limit = c("error", "na"))
```

Passed as `limits =` to any matching function, or set for the session
with `options(zuregex.limits = re_limits(...))`. `NULL` keeps PCRE2's
default. With `on_limit = "na"` the element that hit a limit gives `NA`
and one warning summarises how many did, which is `hs_capture()`'s
behaviour today.

### 5.6 Threads and the cache

```r
re_threads(n = NULL)        # get or set the thread cap, as rng_threads()
re_cache_size(n = NULL)     # get or set the cache capacity
re_cache_clear()
```

### 5.7 Callouts (later, §14)

```r
re_detect("\\w+(?C1)(*FAIL)", x, callout = function(block) "pass")
```

The callback receives the callout number or string, the current
position, the start of the match and the groups so far, and returns
`"pass"`, `"fail"` (backtrack from here) or `"abort"`, as in pcre2.py.
Shown here because it shapes the API; it ships after v0.1.0.

## 6. Semantics

### 6.1 Strings, bytes and encodings

- Character input is matched as UTF-8 with `PCRE2_UTF`. Strings in other
  declared encodings are translated in phase 1; `NA` in gives `NA` out.
- Raw vectors and `useBytes`-marked strings are matched as bytes, without
  `PCRE2_UTF`, which is go-re2's `CompileLatin1` idea. Offsets are then
  byte offsets.
- Invalid UTF-8 in character input is an error, as in base R, unless the
  pattern is compiled for bytes. File scanning (§14) uses
  `PCRE2_MATCH_INVALID_UTF`, so a stray byte never stops a scan.

### 6.2 Offsets

One-based and inclusive, in characters, as `regexpr()` and
`stringr::str_locate()` report them, so `substr(x, start, end)` and, for
raw input, `x[start:end]` extract a match directly. An empty match at
position `k` has `start = k` and `end = k - 1`, as in `str_locate()`, so
`substr()` gives `""`. No match gives `NA`. `bytes = TRUE` gives byte
offsets in the same convention. The C API uses zero-based, half-open byte
offsets, as C code and `vectorscan` expect.

### 6.3 Defaults

The default dialect is base R's `perl = TRUE` (D2): `PCRE2_UTF` without
`PCRE2_UCP`, without `PCRE2_DOLLAR_ENDONLY`, and PCRE2's own empty-match
rule.
A pattern that works in `grepl(perl = TRUE)` gives the same result in
`re_detect()`; §9's parity tests hold the package to that.

`dialect = "js"` turns on what node-pcre2 enables by default:
`PCRE2_ALT_BSUX`, `PCRE2_EXTRA_ALT_BSUX`, `PCRE2_DOLLAR_ENDONLY`,
`PCRE2_MATCH_UNSET_BACKREF`, and JavaScript's rule for advancing after an
empty match. It is close to ECMA-262, not equal to it (§15).

### 6.4 The pattern cache

A least-recently-used cache of compiled, JIT-compiled patterns keyed by
pattern, flags, dialect and `literal`, sized as PyPcre sizes its global
cache (D4): 128 entries by default, at most 256, and patterns longer than
65,536 characters are never cached. Only the main thread reads or writes
it, so it needs no lock and no per-thread layer, which PyPcre needs for
free-threaded Python. An `re` object bypasses it.

### 6.5 One pattern, or one per element

`pattern` of length one applies to every element of `x`. `pattern` of
length `length(x)` pairs `pattern[i]` with `x[i]`. Any other length is a
`zuregex_error_length`, including lengths that would divide `length(x)`
evenly: nothing is recycled. The same holds for `replacement` and
`template`, independently of `pattern`.

- An `NA` pattern gives an `NA` result for its element.
- `flags`, `dialect` and `literal` apply to every pattern in the call.
- The distinct patterns are found once (by `match()` on the strings) and
  compiled once each. When they fit in the cache they go through it; when
  there are more of them than the cache holds, they are compiled into a
  table that lives only for the call, so one call with 10,000 distinct
  patterns does not flush the cache for everything else.
- In phase 2 each element carries the index of its compiled pattern, and
  threads share the table read-only. Each thread's match data is sized
  for the pattern with the most groups.
- Per-element patterns make the work per element uneven, so the parallel
  loop uses dynamic scheduling. Results stay identical for any thread
  count.
- `re_match()` and `re_match_all()` with differing patterns return the
  union of their groups, in order of first appearance: groups with the
  same name share a column, unnamed groups share a column by position,
  and an element whose pattern lacks a group gets `NA` there. This is
  `hs_capture()`'s rule for several formats.

This is pairwise matching, as in stringr. It is not a pattern set, which
matches many patterns against every element (§14.5).

### 6.6 Threads

OpenMP, exactly as `zurand` sets it up (D5): the `configure` probe that
links R's own `libomp` on macOS, the guard on `_OPENMP` and `<omp.h>`,
and a package thread cap applied per loop with `num_threads()`.

- No cap by default: `omp_get_max_threads()`, which honours
  `OMP_NUM_THREADS` and `OMP_THREAD_LIMIT`.
- `re_threads()` behaves as `rng_threads()`: `NULL` queries, a number
  caps, `0` removes the cap, and setting returns the previous cap so that
  `old <- re_threads(1); re_threads(old)` restores it.
- The package's tests cap at two threads in `tests/testthat/setup.R`, for
  CRAN's two-core limit.
- A call stays serial below a threshold in **total subject bytes**, not
  in element count: `zurand` counts values because each costs the same,
  while a regex's cost grows with the length of the subject. Stage 6
  tunes the threshold.
- Results are identical for any thread count. A call with an R callout
  always runs on one thread.

### 6.7 Limits and untrusted input

PCRE2 backtracks, so `zuregex` makes no linear-time promise. What it
promises is that `limits` bound the work per element, that hitting a
limit is either a classed error or an `NA` the caller asked for, and that
a scan never stalls on one element. For a linear-time guarantee, CRAN's
`re2` package is the answer and the documentation says so.

## 7. The C API

`inst/include/zuregex.h`, registered with `R_RegisterCCallable`. Opaque
handles rather than raw PCRE2 types, so that a PCRE2 upgrade never breaks
a consumer's build:

```c
zr_pattern *zr_compile(const char *pattern, size_t len, uint32_t flags,
                       int dialect, char *errbuf, size_t errlen);
int  zr_match(const zr_pattern *p, const char *subject, size_t len,
              size_t start, zr_match_data *md);
int  zr_substitute(const zr_pattern *p, const char *subject, size_t len,
                   const char *tmpl, size_t tlen, char *out,
                   size_t *outlen);
void zr_free(zr_pattern *p);
const char *zr_version(void);
```

Match data, group lookup by name and limits complete the set. The family's
R10 rules apply: a consumer fixture under `tools/`, a `consumer.yaml`
workflow, and consumers built against the CRAN tarball before each
release.

## 8. Errors

Classed conditions, all inheriting from `zuregex_error`:

- `zuregex_error_compile`: the pattern, the offset and PCRE2's message,
  with a caret under the offending position.
- `zuregex_error_limit`: which limit, at which element.
- `zuregex_error_utf`: invalid UTF-8, at which element and byte.
- `zuregex_error_callout`: an R error raised inside a callout, carried
  out through `R_UnwindProtect` so PCRE2's state is released first.

## 9. Testing

- **Parity with base R,** in go-re2's style: every verb is tested against
  its base R or stringr counterpart on a shared corpus, and every
  deliberate difference is a named test marked `# GAP` with its reason.
- **PCRE2's `testdata/`:** the pattern and subject pairs of the main
  test inputs, run through the C API, as the conformance corpus.
- **Thread invariance:** every verb gives identical results with one
  thread and with several, on inputs above the parallel threshold, with
  one pattern and with one pattern per element.
- **Pattern lengths:** length one and length `length(x)` work, every
  other length errors, and per-element results equal a loop over single
  calls and stringr's pairwise results.
- **Cache:** hits, evictions and that cached and uncached results agree.
- **Fuzzing** with `zufuzz` on compile and match, and the family's
  sanitizer, valgrind and `rchk` legs.

## 10. Performance targets

Hypotheses to measure, not promises:

- `re_detect()` on one million strings, one thread: no slower than
  `grepl(perl = TRUE)`.
- With four threads on a pattern that is not memory-bound: at least
  2.5× faster than one.
- The same pattern in 10,000 short calls: at least 3× faster than base R,
  from the cache.
- `re_match()` against `utils::strcapture()`: at least 10× (`hs_capture()`
  measured 21×).
- The regex-redux benchmark, which pcre2.py publishes, as a cross-language
  check.

## 11. Roadmap

Stages, each one pull request, following the family's CI tier policy:

0. Vendor PCRE2 10.48, build without `cmake`, hide symbols,
   `zuregex_info()`.
1. `re_compile()`, flags, dialects, `re_info()`, `re_escape()`, the
   cache, and the per-element pattern table with its length rule.
2. Detect, count and locate, with `anchor` and `bytes`.
3. Extract and match, with `proto`.
4. Replace (template and function), expand and split.
5. Limits and classed errors.
6. OpenMP, with the thread-invariance tests (**full** tier: the parallel
   paths are what sanitizers exist for).
7. The C API, its consumer fixture, and `vectorscan` switched to it on a
   branch.
8. Full CI.

## 12. Acceptance criteria for v0.1.0

- Every verb in §5.2 to §5.4 passes the base R parity suite, with every
  difference marked `# GAP`.
- The PCRE2 `testdata/` subset passes through the C API.
- Results are identical across thread counts.
- `vectorscan` builds and passes its tests against `zuregex` with its own
  PCRE2 copy removed.
- The source tarball is under 5 MB and R CMD check is clean on the
  r-actions matrix.

## 13. Decisions

Marked **(M)** when the maintainer decided it in the conversation and
**(C)** when this RFC decides it and the maintainer may overturn it.

- **D1 (M).** The engine is vendored PCRE2, 8-bit only, with JIT,
  starting at 10.48 to match `vectorscan`. Ratified by Stage 1
  (2026-10-21), which builds it on every r-actions leg.
- **D2 (M).** Defaults follow base R's `perl = TRUE`, not JavaScript.
  node-pcre2 defaults to JavaScript because its users bring JavaScript
  patterns; R users bring base R patterns. `dialect = "js"` is opt-in.
- **D3 (M).** Functions use the `re_` prefix, matching the family's
  domain prefixes (`json_`, `html_`, `sat_`, `rng_`).
- **D4 (M).** The pattern cache follows PyPcre: 128 entries by default,
  256 at most, nothing over 65,536 characters (§6.4). node-pcre2 and
  pcre2.py have no compile cache; Python's own `re` keeps 512.
- **D5 (M).** OpenMP as in `zurand`, with no cap by default, a
  `rng_threads()`-style `re_threads()`, tests capped at two threads, and
  a serial threshold measured in total subject bytes (§6.6).
- **D6 (M).** One-based inclusive character offsets by default; byte
  offsets on request.
- **D7 (M).** Replacement templates use PCRE2's extended syntax (`$1`,
  `${name}`), not base R's `\\1`. The syntax is richer and is what the
  engine implements; translating base R templates is an open question
  (§15).
- **D8 (M).** `pattern` has length one, for all of `x`, or exactly
  `length(x)`, one per element; any other length is an error and nothing
  is recycled (§6.5). Distinct patterns are compiled once each and shared
  read-only by the threads.
- **D9 (M).** `vectorscan` stays a separate package and reaches PCRE2
  through `LinkingTo: zuregex` and the C API of section 7, dropping its
  own vendored copy. Vectorscan is not vendored here.
- **D10 (M).** Callouts into R run on one thread and arrive after
  v0.1.0; C callouts are part of the C API from the start.
- **D11 (M).** Limits default to PCRE2's defaults with
  `on_limit = "error"`.

## 14. Later versions, in the order they are expected

1. **Files and connections.** `re_scan_file()` and `re_scan_conn()`: the
   subject is read in chunks or memory-mapped, PCRE2's partial matching
   (`PCRE2_PARTIAL_HARD`) carries a match across chunk boundaries, files
   are split by threads at newlines, and only matching lines become R
   strings. Returns line number, offsets and groups.
2. **The lexer.** `re_lex(x, rules)`: named rules compiled into one
   alternation tagged with `(*MARK:name)`, returning a token table of
   type, text, start, end and line in one pass. The lexer front end that
   RFC 0039 lists as a later direction.
3. **R callouts** (§5.7), and `PCRE2_AUTO_CALLOUT` as a pattern
   debugger.
4. **Serialized patterns** through `pcre2_serialize`, so `re` objects
   survive `saveRDS()` and travel to parallel workers; JIT is redone on
   load.
5. **Pattern sets,** go-re2's `Set`: which of many patterns match each
   element. PCRE2 alone needs one pass per pattern; with `vectorscan`
   installed, its prefilter routing makes it one pass.
6. **DFA matching** (`pcre2_dfa_match`), for every match starting at a
   position.

## 15. Open questions

- Whether `re_replace()` should also accept base R's `\\1` templates
  through `syntax = "base"`, to ease porting from `gsub()`.
- Whether `dialect = "js"` passes enough of the JSON Schema Test Suite's
  `pattern` and `format: regex` cases for `zuschema`, or `zuschema` needs
  a translation layer.
- Whether file scanning (§14.1) should move into v0.1.0, since it is the
  most visible new feature for R users and the reason `grepreaper` and
  `findInFiles` exist.
- The installed size of the compiled library with JIT, which decides
  whether R CMD check raises the installed-size NOTE.
- How to mark incubating functions: go-re2 uses an `experimental`
  package; the family uses lifecycle badges.

## 16. What this RFC does not decide

- Whether `vectorscan` joins the `zu*` family. D9 only says it consumes
  `zuregex`.
- Anything about linear-time matching. CRAN's `re2` covers it, and a
  family need for it would be a separate RFC.

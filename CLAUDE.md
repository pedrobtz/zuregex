# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`zuregex` is PCRE2 packaged twice. For R code it is a set of `re_*` verbs
that do what base R's `perl = TRUE` engine cannot: a compiled-pattern cache,
OpenMP matching, captures filled in C, PCRE2's full replacement language and
per-call match limits. For C code it is a library that sibling packages reach
through `LinkingTo` instead of vendoring their own PCRE2. The engine is a
vendored PCRE2, 8-bit with JIT, one version on every platform, with hidden
symbols because R already loads its own `libpcre2-8`. No `Imports`: zero hard
runtime dependencies. It makes no linear-time promise (CRAN's `re2` does),
adds no pattern syntax, and does not ship the 16-bit or 32-bit libraries,
`pcre2grep` or `pcre2test`.

The specification is `.agents/design.md`, adopted from
[RFC 0042](https://github.com/pedrobtz/packages/blob/main/rfcs/started/0042-zuregex-pcre2-for-r-and-c.md)
in `pedrobtz/packages`. It outranks this file: `CLAUDE.md` orients, the
design decides. Its decisions (§13) are settled; its open questions (§15)
stay open until the roadmap or a stage settles them.

## Current state

PCRE2 10.48 is vendored and builds on every platform (Stage 1). Patterns
compile, with flags, dialects and a cache (Stage 2); no verb matches yet. The
roadmap in `.agents/roadmap.md` takes it to v0.1.0; §11 of the
design lists the stages it is expected to hold.

## Stage tracking

Progress toward the next version is tracked as GitHub sub-issues, so the
parent issue shows a progress bar such as "6 of 7".

- **One parent issue per target version**, titled with the bare version, for
  example `v0.1.0`. `v0.1.0` issue: created by `pkg-roadmap`.
- **One sub-issue per roadmap stage**, titled as the roadmap titles it, for
  example `Stage 3 — R interface`, and linking to that section. The number of
  stages is whatever the roadmap has; there is no fixed scale.
- **Every tracking issue carries the `stage` label**, so it can be told apart
  from bug and feature issues and left out of open-issue counts.
- **Close a stage by merging its pull request.** Put `Closes #<n>` in the
  body of the stage's pull request. Never close a stage whose exit criteria
  are not met; record a deviation in the roadmap first.
- **The roadmap stays authoritative.** The issues record which stages are
  done, not what a stage requires. Adding, removing or renaming a stage
  means editing the roadmap and the sub-issues in the same change.
- **Each stage has a CI tier, `quick` or `full`.** The roadmap sets it, and
  `quick` is the default. See Continuous integration for what each means.
  The second-to-last stage, `Full CI`, runs the full set and fixes what it
  finds before `v0.1.0 readiness`.
- Close the parent issue when CRAN accepts the version and it is tagged.
  Opening a parent issue implies at least one stage sub-issue; a parent with
  no sub-issues shows no progress on the board.

## Versioning

A new package develops at `0.0.0.9000` and targets `0.1.0` for its first CRAN
release. Set `Version: 0.1.0` and the matching `NEWS.md` heading when the
package enters `Pre-flight`. Bump to `0.1.0.9000` only after CRAN accepts it,
never before: a `.9000` version above an unreleased `0.1.0` heading is wrong.

Until the first release the R API may change freely. Sibling packages can
still depend on this one before CRAN does, through `Remotes:` or `LinkingTo:`.
The design (§3) names four consumers of the C API: `vectorscan`, which drops
its own PCRE2 copy for it, and the planned `zutoken`, `zuschema` and `zupeg`.
A change to the C API, a header in `inst/include/` or a static archive breaks
them even before 0.1.0. A package that others wait on should reach CRAN
first.

## Commands

Run from the package root.

```sh
Rscript -e 'devtools::load_all()'                # compile src/ and load
Rscript -e 'devtools::document()'                # roxygen -> NAMESPACE, man/
Rscript -e 'devtools::test()'                    # full testthat suite
Rscript -e 'devtools::test(filter = "<name>")'   # one test file
Rscript -e 'devtools::test(shuffle = TRUE)'      # order independence
Rscript -e 'devtools::check()'                   # R CMD check
air format .                                     # format R sources
```

```sh
tools/vendor/verify              # vendored tree = upstream + declared patches
tools/vendor/verify --offline    # the same without re-deriving from upstream
tools/vendor/fetch               # re-vendor from tools/vendor/manifest.tsv
```

The benchmark harness arrives with its stage; add it here when it does.

## Architecture

Written as stages land; see `.agents/design.md` §4 for the planned shape,
a three-phase split where only the middle, OpenMP phase runs without the R
API.

- `src/init.c` registers the `.Call` routines and is the only exported
  symbol, `R_init_zuregex`, marked `attribute_visible`.
- `src/zuregex.h` declares the first-party native routines.
- `src/info.c` backs `zuregex_info()`.
- `src/vendor/pcre2/` is PCRE2 with its upstream layout; `src/Makevars`
  lists its 31 units in `PCRE2_OBJECTS` and builds it without CMake.
  `src/pcre2-config/config.h` is the package's own PCRE2 configuration.
- `src/pattern.c` turns flag letters into PCRE2 options and owns
  `zuregex_pattern`, a compiled pattern with a reference count.
  `src/pattern.h` has no R API, so later stages can read patterns from
  worker threads.
- `src/cache.c` is the LRU pattern cache; `src/compile.c` holds the R
  entry points for `re_compile()`, `re_info()` and the cache.
- An `re` object is a list of external pointers, each holding one
  reference, with the pattern, flags, dialect, literal and jit as
  attributes. `re_restore()` recompiles pointers that `saveRDS()` nulled.
- `R/errors.R` has `zuregex_abort()` and the argument checks.

## Invariants that are easy to break

These are the constraints the design already fixes. Add each new one when a
stage establishes it.

- **Zero hard runtime dependencies.** `DESCRIPTION` has no `Imports`.
  Anything beyond base R goes in `Suggests` and is guarded.
- **The OpenMP phase never touches the R API** (design §4). `STRING_ELT`,
  translation and allocation can allocate or run R code, so they belong in
  the serial phases before and after. A call into R from a worker thread is
  a crash that only shows up under load.
- **Results are identical for any thread count** (design §6.6). Tests cap at
  two threads in `tests/testthat/setup.R`; a result that depends on the cap
  is a bug, not a tuning question.
- **The pattern cache is main-thread only** (design §6.4). It has no lock
  because nothing else reads or writes it. Touching it from phase 2 breaks
  that assumption silently.
- **Vendored PCRE2 symbols are hidden** (design §4). R has its own
  `libpcre2-8` loaded, so an exported symbol can bind to R's copy, a
  different version with different behaviour.
- **Two offset conventions, deliberately** (design §6.2). R results are
  one-based, inclusive and in characters; the C API is zero-based,
  half-open and in bytes. Convert at the boundary, never in the middle.
- **A pattern's reference count is main-thread only.** The cache, each
  `re` external pointer and its finalizer own references. A worker thread
  may read a `zuregex_pattern`, never retain or release one.
- **PCRE2 is built with `LINK_SIZE 4`** (`src/pcre2-config/config.h`).
  With upstream's 2, patterns well under the cache's 65,536-character
  limit fail to compile.
- **The C API uses opaque handles** (design §7), so a PCRE2 upgrade never
  breaks a consumer's build. Exposing a raw `pcre2_code` in
  `inst/include/zuregex.h` ties every consumer to one PCRE2 version.

## Testing conventions

- **Self-sufficient.** Every test builds its own inputs inside the
  `test_that()` block. No file-scope objects.
- **Self-contained.** Global state goes through `withr::local_*()`, randomised
  input through `withr::local_seed()`. Tests write only under `tempdir()`.
- **Assert on condition classes, never message text.** Use
  `expect_error(..., class = "<pkg>_<kind>_error")`. Wording belongs in
  snapshot tests.
- **Order independence.** `devtools::test(shuffle = TRUE)` is part of the
  definition of done.
- **Borrow a conformance suite before writing one.** Mainstream
  implementations in Python, Java, Go or Node usually ship a test corpus.
  Use it as an oracle rather than inventing cases by hand. The design (§9)
  names two oracles: PCRE2's own `testdata/` through the C API, and base R's
  `perl = TRUE` and stringr for parity, with every deliberate difference
  marked `# GAP`. Neither is wired up yet.
- **Helpers live in `tests/testthat/helper-*.R`.** `helper-symbols.R` runs
  `nm` on the loaded shared object; `helper-types.R` has small predicates.
- **Keep the suite inside the CRAN time budget.** Only the placeholder test
  exists; record the runtime once the suite has one.

## Definition of done

`devtools::document()` and `devtools::check()` clean, meaning 0 errors, 0
warnings and 0 notes. The one allowed note is "New submission" before the first
release. `devtools::test(shuffle = TRUE)` green. CI green at the change's
tier: the quick profile for a `quick` roadmap stage or an ordinary pull
request, the full profile for a `full` stage, `Full CI`, and every release.
A user-facing change also needs a test, roxygen documentation and a `NEWS.md`
entry.

## Releasing to CRAN

- **CI is the pre-submission check.** The `pedrobtz/r-actions` R CMD check runs
  `--as-cran` on the CRAN-like runners and containers, and it replaces
  win-builder, the macOS builder and R-hub. None of them is a release step,
  and `cran-comments.md` lists the CI legs as its test environments.
- **Entering `Pre-flight`.** The roadmap's feature stages are done, the
  version is set as in Versioning, `NEWS.md` and `cran-comments.md` are
  written, and CI is green. Only submission work remains.
- **Before submitting,** run `pkg-critical-review` once the roadmap is
  implemented and fix what it files, then `pkg-cran-review`, and resolve
  every finding. Both skills are in `pedrobtz/r-skills`.
- **The pretest is automated and does not read `cran-comments.md`.** A NOTE
  that is explained but not fixed gets the upload archived. Fix the NOTE, as
  under Vendored native code, instead of justifying it.
- **After acceptance,** `pkg-post-cran` tags the submitted commit with the
  bare version, `0.1.0` (no `v`), publishes the GitHub release, bumps to
  `0.1.0.9000`, closes the version's parent issue and moves the board card.

## Editing rules

- roxygen comments are the source. Never edit `man/` or `NAMESPACE` by hand.
- Edit `README.Rmd`, not the generated `README.md`.
- Keep prose simple and short. One idea per sentence.
- Wrap roxygen text at 80 characters and run `air format .` on R sources.
- Use `lower_snake_case`, and prefix internal native symbols with `<pkg>_`.
- Keep hard runtime dependencies at zero unless a recorded design decision
  says otherwise.
- Export and document public functions. Do not create roxygen topics for
  internal ones.

## Continuous integration

Workflows come from `pedrobtz/r-actions`. Call those reusable workflows instead
of writing bespoke ones, and pin a released tag rather than `main`. Pin a
workflow that holds a write token, such as `coverage.yml`, to a commit, with
the tag in a comment. The `R-CMD-check` workflow must call `r-cmd-check.yml`,
because a hand-rolled one does not count as the pre-submission check. This
package calls `r-cmd-check.yml` from `.github/workflows/R-CMD-check.yaml`,
with the `quick`/`full` profile chosen by event and the `full-ci` label, and
`coverage.yml` from `.github/workflows/coverage.yaml`. The pkgdown site is
built by `.github/workflows/pkgdown.yaml`, the `r-lib/actions` example
workflow.

A ruleset requires pull requests on `main`, so the coverage badge cannot be
committed there. `coverage.yaml` sets `badge-branch: gh-pages`, and the
pkgdown deploy sets `force: false` so it rebases over the badge commit
instead of overwriting it. Keep both, and keep the README badge pointing at
`gh-pages/badges/coverage.svg`.

Small edits get a small run. The shared workflows look at the files a pull
request changes, compared with its merge base:

- **Markdown only**, such as `README.md`, `NEWS.md` or `cran-comments.md`,
  skips every check. Only coverage and the pkgdown site run.
- **`DESCRIPTION` or `README.Rmd` as well**, and nothing else, adds one R CMD
  check on Ubuntu R-release.
- **Any other file** runs everything.

So put a README or `DESCRIPTION` touch-up in its own pull request. Once a pull
request changes code, every later push to it runs every workflow.

### Quick by default, full by exception

The full profile is slow. gctorture at step 20 alone has taken 36 to 107
minutes on sibling packages. Waiting on it between roadmap stages was the
main thing slowing roadmaps down, so:

- **Pull requests run the quick profile.** It should finish in under five
  minutes. If it doesn't, raise gctorture's `quick-step` or trim
  `quick-containers` in the caller workflows; never cut the full profile.
- **A `full` roadmap stage takes the `full-ci` label** and merges only on a
  green full run. The roadmap gives the reason in the stage's `**CI.**`
  line, for example first compiled code, a `PROTECT` or finalizer change, a
  vendored library, or a Windows-only path.
- **Don't wait on the full run a merge starts** on the default branch, and
  cancel older full runs it supersedes. A failure that only the full set
  shows goes on the `Full CI` stage issue as a comment with the run link,
  and is fixed there. A failure the quick profile also shows is fixed now.
- **`Full CI` and `v0.1.0 readiness` wait** for a green full run on their
  merge commit, and the release commit always needs one.
- Locally, run `gctorture(TRUE)` on the code a C change touches when it is
  cheap; the full run is the authority.

## Vendored native code

The design vendors PCRE2, 8-bit with JIT, BSD-3-Clause with the PCRE2
binary-library exception, starting at 10.48 to match `vectorscan` (design
D1). Vendored in Stage 1:

| | |
| --- | --- |
| Tag | `pcre2-10.48` |
| Commit | `7978954dbd2efc6f2196869290553cf1871b4ce6` |
| Archive SHA-256 | `ebcc25aadf2a51fa1fefa9b8bc9e7a79b3dae86870a0f1152a22e42befd46888` |
| Per-file checksums | `tools/vendor/checksums.sha256` |
| Patches | `tools/patches/pcre2/`, listed in `src/vendor/PROVENANCE` |

`src/vendor/PROVENANCE` holds the update procedure. `tools/vendor/verify`
checks that the manifest, `PROVENANCE`, `inst/COPYRIGHTS`, `src/Makevars`
and `tests/testthat/test-info.R` agree, so a bump that forgets one fails.
`tests/testthat/test-abi.R` is the `nm` guard: it fails on any exported
symbol but `R_init_zuregex` and on any linked stdio, exit, abort or RNG
symbol, on every CI leg.

- Pin a stable upstream release, never `master` or a release candidate.
- Record the tag, the commit and the checksums, and write down the update
  procedure so the next bump is mechanical.
- Keep upstream `LICENSE` and `NOTICE` under `src/vendor/<lib>/`, declare the
  vendored code in `DESCRIPTION` and `inst/COPYRIGHTS`.
- Keep the vendor tree clearly separated from first-party source, and record
  every local patch and why it exists.
- **CRAN's compiled-code check applies to vendored code too.** No `stdout` or
  `stderr`, no `printf`, `abort`, `exit` or system RNG may be linked, even
  behind a debug switch that never runs. Remove them with a patch in
  `tools/patches/`, list it in `src/vendor/PROVENANCE`, and make the
  vendor-verify script check "upstream plus exactly these patches". Avoid
  diagnostic-suppressing pragmas too, because they draw their own NOTE. zuhtml
  is the reference: `tools/patches/0002-no-stdio.patch` and
  `tools/verify-vendor`. zuxml's first upload was archived because it
  justified such a symbol instead of patching it.
- Guard against regressions in CI: run `nm -u` on the built objects and fail
  on any of those symbols, so an upstream bump cannot bring them back.

## Commits and pull requests

Short, imperative, sentence-case commit subjects, optionally scoped. Keep each
commit focused and do not sweep in unrelated files. A pull request explains the
user-visible outcome and the rationale, links related issues, lists the checks
that were run and the tests that were skipped, and flags platform-sensitive or
vendored changes. Performance claims need evidence.

Never commit or push to the default branch. Work on a branch, open a pull
request, and leave it for review. Do not merge a pull request unless you are
told to.

When you find a defect, in this package or in an upstream tool, open an issue
for it rather than only working around it.

## Working with skills

The portfolio's workflow skills live in `pedrobtz/r-skills` (`pkg-init`,
`pkg-roadmap`, `pkg-implement`, `pkg-critical-review`, `pkg-cran-review`,
`pkg-post-cran`, `pkg-readme`); the general process skills are
[Superpowers](https://github.com/obra/superpowers). `building-a-package.md`
in `pedrobtz/packages` walks through them in order. Both sets defer to this
file where they overlap, so the settlements are recorded here.

- **One design.** The specification is `.agents/design.md`, adopted from the
  package's RFC in `pedrobtz/packages/rfcs`. A package with an adopted design
  is past `brainstorming`; a design change goes through the RFC, not a new
  spec. Superpowers' default `docs/superpowers/specs/` is not used.
- **Plans at two levels.** `.agents/roadmap.md` holds the stages, one
  mergeable pull request each, with exit criteria and a CI tier
  (`pkg-roadmap`). Inside a stage, `writing-plans` breaks the work into
  tasks of one test cycle each, saved as `.agents/plans/stage-<n>.md`. The
  roadmap stays authoritative; a plan is scratch and is not kept in sync.
- **Build and merge.** `pkg-implement` runs the stage loop: branch
  `stage-<n>-<slug>` from the stage issue, implement the plan with
  `test-driven-development` (`Rscript -e 'devtools::test(filter = "<name>")'`
  is the red/green command), open the pull request, merge on green at the
  stage's CI tier. The confirmation the user gives at the start of that
  loop is the "told to merge" that Commits and pull requests requires, so
  the `finishing-a-development-branch` menu is not presented for stage
  pull requests. Any other pull request still waits for review.
- **Failures and claims.** A failing check or test goes through
  `systematic-debugging` before a fix. "Green", "done" and "ready for CRAN"
  are claimed only after `verification-before-completion`: run the command,
  read the output.
- **Review.** `requesting-code-review` gates tasks inside a stage.
  `pkg-critical-review` reviews the whole package once the roadmap is
  implemented, with Posit's reviewers, and files issues. CRAN's reviewer
  email and GitHub review threads go through `receiving-code-review`.
- **Keep scratch out of the tarball.** `R CMD build` reads `.Rbuildignore`,
  not `.gitignore`. It must list `^\.agents$`, `^\.superpowers$` (the
  Superpowers task ledger), `^\.worktrees$` (if git worktrees are kept in
  the package directory; a sibling directory avoids the question),
  `^\.claude$`, `^CLAUDE\.md$`, `^AGENTS\.md$`, `^CRAN-SUBMISSION$` and
  `^cran-comments\.md$`. A stray top-level file is a NOTE, and the pretest
  archives on NOTEs.

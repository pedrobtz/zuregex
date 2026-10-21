## Submission

This is a new submission.

zuregex bundles PCRE2 (<https://github.com/PCRE2Project/pcre2>, version
10.48), the 8-bit library with its just-in-time compiler, in
`src/vendor/pcre2/`, so it needs no system library and every platform runs
the same version. It is built without CMake, and every PCRE2 symbol is
hidden, so it cannot bind to the PCRE2 R itself loads.

## Test environments

* local macOS, R 4.5.2
* GitHub Actions: ubuntu-latest (R release, oldrel-1), macOS-latest
  (R release), windows-latest (R release, R-devel)
* R-hub containers, R-devel: `clang23`, `ubuntu-clang`, `ubuntu-gcc16`
* UBSan, ASan, valgrind, gctorture, rchk, LTO and `-fanalyzer`

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Bundled code

PCRE2 is BSD-3-Clause with the PCRE2 exception, and its JIT compiler
(sljit) BSD-2-Clause; zuregex's own code is MIT. `inst/COPYRIGHTS`
reproduces the copyright notices, and the PCRE2 copyright holders are
listed as `cph` in `Authors@R`.

The vendored tree carries one patch, listed in `src/vendor/PROVENANCE`: it
splits one long string literal so that no literal exceeds what ISO C99
requires compilers to support. No message changes.

## Threads

Matching uses OpenMP on large inputs. The tests cap it at two threads.

## Network use

Tests, examples and vignettes do not use the network.

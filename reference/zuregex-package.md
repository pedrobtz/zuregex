# zuregex: Bundled 'PCRE2' Regular Expressions with a C Interface

Matches regular expressions with a bundled copy of the 'PCRE2' library
(<https://github.com/PCRE2Project/pcre2>), so that every platform runs
the same version with its just-in-time compiler. Patterns are compiled
once and cached, matching runs on several threads, and capture groups
are returned as character vectors and data frames built in C.
Replacements use the full 'PCRE2' substitution language, and each call
can bound its work with match, depth and heap limits. Other packages
reach the same library from C through 'LinkingTo', instead of bundling
their own copy.

## See also

Useful links:

- <https://github.com/pedrobtz/zuregex>

- <https://pedrobtz.github.io/zuregex/>

- Report bugs at <https://github.com/pedrobtz/zuregex/issues>

## Author

**Maintainer**: Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Authors:

- Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Other contributors:

- Philip Hazel (Author of PCRE2, bundled in src/vendor/pcre2)
  \[contributor, copyright holder\]

- University of Cambridge (PCRE2, bundled in src/vendor/pcre2)
  \[copyright holder\]

- Zoltan Herczeg (Author of the PCRE2 JIT compiler and sljit, bundled in
  src/vendor/pcre2) \[contributor, copyright holder\]

- Nicholas Wilson (PCRE2 maintainer, bundled in src/vendor/pcre2)
  \[contributor\]

- PCRE2 contributors (see inst/COPYRIGHTS) \[copyright holder\]

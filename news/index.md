# Changelog

## zuregex (development version)

- Bundles PCRE2 10.48, the 8-bit library with its JIT compiler, built
  without CMake and with every PCRE2 symbol hidden from R’s own copy.
- [`zuregex_info()`](https://pedrobtz.github.io/zuregex/reference/zuregex_info.md)
  reports the bundled PCRE2 version and whether its JIT compiler works
  on this machine.

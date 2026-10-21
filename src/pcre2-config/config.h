/* PCRE2 build configuration for zuregex.
 *
 * Hand-written in place of the config.h that CMake or configure would
 * generate (PCRE2's NON-AUTOTOOLS-BUILD, step 1), so the package builds with
 * neither. Every vendored unit includes it through -DHAVE_CONFIG_H, and finds
 * it through -Ipcre2-config in src/Makevars.
 *
 * Only the macros PCRE2 10.48 reads are set. On an upgrade, compare this file
 * with src/config.h.generic of the new release: upstream has changed what
 * some of these mean between releases. Limits that callers can change at run
 * time keep upstream's defaults. */

#ifndef ZUREGEX_PCRE2_CONFIG_H
#define ZUREGEX_PCRE2_CONFIG_H

/* The library: 8-bit code units, Unicode and UTF-8, and the JIT compiler.
 * sljit picks the target from the compiler's predefined macros; on a CPU it
 * does not support, pcre2_jit_compile() returns an error at run time and
 * matching falls back to the interpreter (zuregex_info() reports it). */
#define SUPPORT_PCRE2_8 1
#define SUPPORT_UNICODE 1
#define SUPPORT_JIT 1

/* Statically linked into zuregex.so. PCRE2_EXPORT is left empty, so the
 * public functions take $(C_VISIBILITY) like every other symbol and stay
 * hidden: R has its own libpcre2-8 loaded (design section 4). PCRE2_STATIC
 * comes from src/Makevars, since first-party units include pcre2.h too. */
#define PCRE2_EXPORT

/* Headers and functions every platform R supports provides. */
#define HAVE_INTTYPES_H 1
#define HAVE_LIMITS_H 1
#define HAVE_MEMMOVE 1
#define HAVE_STDINT_H 1
#define HAVE_STDIO_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRERROR 1
#define HAVE_STRING_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#if !defined(_WIN32)
#define HAVE_UNISTD_H 1
#endif

/* pcre2_chkdint.c uses the builtin when the compiler has it, and its own
 * overflow check otherwise. GCC and clang, the compilers R uses, have it. */
#if defined(__GNUC__) || defined(__clang__)
#define HAVE_BUILTIN_MUL_OVERFLOW 1
#endif

/* Four-byte internal links instead of upstream's two, so a compiled
 * pattern may exceed 64 KiB. The cache holds patterns of up to 65,536
 * characters and compiles longer ones for the call (design section 6.4);
 * with two-byte links, much shorter patterns already fail with "regular
 * expression is too large". The cost is a slightly larger compiled
 * pattern. */
#define LINK_SIZE 4

/* Upstream's defaults, written out so a reader does not have to look them
 * up. LF is base R's newline convention for perl = TRUE. */
#define NEWLINE_DEFAULT 2
#define HEAP_LIMIT 20000000
#define MATCH_LIMIT 10000000
#define MATCH_LIMIT_DEPTH MATCH_LIMIT
#define MAX_NAME_COUNT 10000
#define MAX_NAME_SIZE 128
#define MAX_VARLOOKBEHIND 255
#define PARENS_NEST_LIMIT 250

#endif

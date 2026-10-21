/* zuregex's C API: PCRE2 for other packages' C code (design section 7).
 *
 * This header is plain C99 and names neither R nor PCRE2. Handles are
 * opaque, so a PCRE2 upgrade inside zuregex never changes a consumer's
 * build. R packages reach the functions through <zuregex-r.h>, which
 * fetches them from zuregex's registered function table.
 *
 * Conventions, unlike the R functions: offsets are zero-based, half-open
 * and in bytes. Strings are UTF-8 unless a pattern is compiled with
 * ZR_BYTES. No function raises an R error, allocates an R object or calls
 * back into R, so all of them are safe to call from any thread, as long as
 * one zr_match_data is used by one thread at a time.
 *
 * Copyright (c) 2026 Pedro Baltazar. MIT licence; see the LICENSE file.
 */

#ifndef ZUREGEX_H
#define ZUREGEX_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* A compiled pattern, read-only once compiled: threads may share it. */
typedef struct zr_pattern zr_pattern;

/* Where a match's offsets go, and the limits it runs under. One per
 * thread. */
typedef struct zr_match_data zr_match_data;

/* zr_compile() flags, the bit form of re_compile()'s letters. */
#define ZR_CASELESS          0x00000001u /* i */
#define ZR_MULTILINE         0x00000002u /* m */
#define ZR_DOTALL            0x00000004u /* s */
#define ZR_EXTENDED          0x00000008u /* x */
#define ZR_EXTENDED_MORE     0x00000010u /* xx */
#define ZR_NO_AUTO_CAPTURE   0x00000020u /* n */
#define ZR_UNGREEDY          0x00000040u /* U */
#define ZR_DUPNAMES          0x00000080u /* J */
#define ZR_UCP               0x00000100u /* u */
#define ZR_CASELESS_RESTRICT 0x00000200u /* r */
#define ZR_ASCII_BSD         0x00000400u /* aD */
#define ZR_ASCII_BSS         0x00000800u /* aS */
#define ZR_ASCII_BSW         0x00001000u /* aW */
#define ZR_ASCII_DIGIT       0x00002000u /* aT */
#define ZR_ASCII_POSIX       0x00004000u /* aP */
#define ZR_LITERAL           0x00010000u /* the pattern is a literal string */
#define ZR_BYTES             0x00020000u /* match bytes, without UTF-8 */
#define ZR_NO_JIT            0x00040000u /* do not JIT-compile */

/* Dialects, as re_compile()'s `dialect`. */
#define ZR_DIALECT_PCRE 0
#define ZR_DIALECT_JS   1

/* zr_match() options. */
#define ZR_ANCHORED     0x00000001u /* match only at `start` */
#define ZR_ENDANCHORED  0x00000002u /* the match must end the subject */
#define ZR_NOTEMPTY     0x00000004u /* an empty match is not a match */
#define ZR_NOTEMPTY_ATSTART 0x00000008u /* nor an empty match at `start` */
#define ZR_NO_JIT_MATCH 0x00000010u /* run the interpreter, not JIT code: a
                                       retry after ZR_ERROR_JIT_STACK */

/* zr_substitute() options. */
#define ZR_SUBSTITUTE_GLOBAL  0x00000001u /* every match, not the first */
#define ZR_SUBSTITUTE_LITERAL 0x00000002u /* the template is literal text */

/* Status codes. zr_match() returns the number of pairs set (at least 1)
 * on a match; everything else returns ZR_OK on success. */
#define ZR_OK                  0
#define ZR_NOMATCH            -1  /* no match */
#define ZR_ERROR_MATCH_LIMIT  -2  /* the match limit was hit */
#define ZR_ERROR_UTF          -3  /* the subject is not valid UTF-8 */
#define ZR_ERROR_NOMEMORY     -4  /* out of memory, or an output buffer too small */
#define ZR_ERROR_ARGUMENT     -5  /* a NULL pointer, bad option or bad offset */
#define ZR_ERROR_TEMPLATE     -6  /* a malformed substitution template */
#define ZR_ERROR_GROUP        -7  /* no such group */
#define ZR_ERROR_OTHER        -8  /* anything else PCRE2 reports */
#define ZR_ERROR_DEPTH_LIMIT  -9  /* the depth limit was hit */
#define ZR_ERROR_HEAP_LIMIT  -10  /* the heap limit was hit */
#define ZR_ERROR_JIT_STACK   -11  /* JIT code ran out of stack: retry with
                                     ZR_NO_JIT_MATCH */

/* "PCRE2 x.y yyyy-mm-dd / zuregex a.b.c": both versions, for diagnostics. */
typedef const char *(*zr_version_fn)(void);

/* Compiles `pattern` (`len` bytes, not necessarily NUL-terminated) with
 * `flags` and `dialect`. Returns NULL on failure and, when errbuf is not
 * NULL, writes a message there with the byte offset of the error. Free the
 * result with zr_free(). */
typedef zr_pattern *(*zr_compile_fn)(const char *pattern, size_t len,
                                     uint32_t flags, int dialect,
                                     char *errbuf, size_t errlen);

typedef void (*zr_free_fn)(zr_pattern *p);

/* Capture groups, not counting group 0. */
typedef int (*zr_group_count_fn)(const zr_pattern *p);

/* The number of the group called `name`, or ZR_ERROR_GROUP. */
typedef int (*zr_group_number_fn)(const zr_pattern *p, const char *name);

/* The name of group `group`, or NULL when it has none. Valid while `p` is. */
typedef const char *(*zr_group_name_fn)(const zr_pattern *p, int group);

/* Whether `p` runs JIT-compiled code. */
typedef int (*zr_jit_fn)(const zr_pattern *p);

/* Match data with room for `p`'s groups (and any pattern with no more).
 * NULL when out of memory. */
typedef zr_match_data *(*zr_match_data_create_fn)(const zr_pattern *p);
typedef void (*zr_match_data_free_fn)(zr_match_data *md);

/* Limits for every match run with `md`; 0 keeps PCRE2's default. `heap` is
 * in kibibytes. */
typedef int (*zr_set_limits_fn)(zr_match_data *md, uint32_t match,
                                 uint32_t depth, uint32_t heap);

/* Searches `subject` (`len` bytes) from byte `start`. Returns the number of
 * offset pairs set, ZR_NOMATCH, or a negative ZR_ERROR_* code. */
typedef int (*zr_match_fn)(const zr_pattern *p, const char *subject,
                           size_t len, size_t start, uint32_t options,
                           zr_match_data *md);

/* The byte offsets of group `group` (0 is the whole match) of the last
 * match in `md`: *start and *end, half-open. Returns ZR_OK, ZR_NOMATCH for
 * a group that did not take part, or ZR_ERROR_GROUP. */
typedef int (*zr_offsets_fn)(const zr_match_data *md, int group,
                             size_t *start, size_t *end);

/* Replaces the first match, or every match with ZR_SUBSTITUTE_GLOBAL, of
 * `p` in `subject` by `tmpl` in PCRE2's extended syntax ($1, ${name},
 * ${1:-default}, \U...\E) or, with ZR_SUBSTITUTE_LITERAL, as text. Writes
 * the result to `out` and its length to *outlen, which holds the size of
 * `out` on entry. If `out` is too small, returns ZR_ERROR_NOMEMORY and sets
 * *outlen to the size needed. Returns the number of replacements, or a
 * negative ZR_ERROR_* code. `md` supplies the limits and may be NULL. */
typedef int (*zr_substitute_fn)(const zr_pattern *p, const char *subject,
                                size_t len, const char *tmpl, size_t tlen,
                                uint32_t options, zr_match_data *md,
                                char *out, size_t *outlen);

/* A message for a status code. Never NULL. */
typedef const char *(*zr_strerror_fn)(int code);

#ifdef __cplusplus
}
#endif

#endif /* ZUREGEX_H */

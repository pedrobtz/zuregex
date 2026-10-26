// Flag letters, compilation and reference counting of compiled patterns.

#include <stdlib.h>
#include <string.h>

#include "pattern.h"

// The flag letters of design section 5.1, in the canonical order
// zuregex_format_flags() writes them.
typedef struct {
  const char *letters;
  uint32_t options;
  uint32_t extra;
} flag_def;

static const flag_def flag_defs[] = {
  {"i", PCRE2_CASELESS, 0},
  {"m", PCRE2_MULTILINE, 0},
  {"s", PCRE2_DOTALL, 0},
  {"xx", PCRE2_EXTENDED_MORE, 0},
  {"x", PCRE2_EXTENDED, 0},
  {"n", PCRE2_NO_AUTO_CAPTURE, 0},
  {"U", PCRE2_UNGREEDY, 0},
  {"J", PCRE2_DUPNAMES, 0},
  {"u", PCRE2_UCP, 0},
  {"r", 0, PCRE2_EXTRA_CASELESS_RESTRICT},
  {"aD", 0, PCRE2_EXTRA_ASCII_BSD},
  {"aS", 0, PCRE2_EXTRA_ASCII_BSS},
  {"aW", 0, PCRE2_EXTRA_ASCII_BSW},
  {"aT", 0, PCRE2_EXTRA_ASCII_DIGIT},
  {"aP", 0, PCRE2_EXTRA_ASCII_POSIX},
};
#define N_FLAGS (sizeof(flag_defs) / sizeof(flag_defs[0]))

#define ASCII_ALL                                                  \
  (PCRE2_EXTRA_ASCII_BSD | PCRE2_EXTRA_ASCII_BSS |                 \
   PCRE2_EXTRA_ASCII_BSW | PCRE2_EXTRA_ASCII_DIGIT |               \
   PCRE2_EXTRA_ASCII_POSIX)

// PCRE2_LITERAL accepts only these of the letters' options
// (PUBLIC_LITERAL_COMPILE_OPTIONS in pcre2_compile.c).
#define LITERAL_OPTIONS PCRE2_CASELESS
#define LITERAL_EXTRA PCRE2_EXTRA_CASELESS_RESTRICT

// What dialect = "js" adds (design section 6.3, node-pcre2's defaults).
#define JS_OPTIONS \
  (PCRE2_ALT_BSUX | PCRE2_DOLLAR_ENDONLY | PCRE2_MATCH_UNSET_BACKREF)
#define JS_EXTRA PCRE2_EXTRA_ALT_BSUX

int zuregex_parse_flags(const char *flags, int literal, uint32_t *options,
                        uint32_t *extra) {
  uint32_t o = 0, e = 0;
  size_t n = strlen(flags);
  for (size_t i = 0; i < n;) {
    const flag_def *def = NULL;
    size_t len = 0;
    if (flags[i] == 'a' && (i + 1 >= n || !strchr("DSWTP", flags[i + 1]))) {
      // `a` alone sets every ASCII restriction. It still counts as a
      // repeat if any of them is already set.
      if ((e & ASCII_ALL) || literal) return (int) i + 1;
      e |= ASCII_ALL;
      i += 1;
      continue;
    }
    // Longest match first, so that "xx" is read before "x".
    for (size_t k = 0; k < N_FLAGS; k++) {
      size_t l = strlen(flag_defs[k].letters);
      if (l > len && i + l <= n && memcmp(flags + i, flag_defs[k].letters, l) == 0) {
        def = &flag_defs[k];
        len = l;
      }
    }
    if (def == NULL) return (int) i + 1;
    // A repeat, or x beside xx, is an error rather than a no-op: "xxx"
    // has no single reading.
    int ext_conflict = (def->options & (PCRE2_EXTENDED | PCRE2_EXTENDED_MORE)) &&
                       (o & (PCRE2_EXTENDED | PCRE2_EXTENDED_MORE));
    if ((o & def->options) || (e & def->extra) || ext_conflict) {
      return (int) i + 1;
    }
    if (literal && ((def->options & ~LITERAL_OPTIONS) ||
                    (def->extra & ~LITERAL_EXTRA))) {
      return (int) i + 1;
    }
    o |= def->options;
    e |= def->extra;
    i += len;
  }
  *options = o;
  *extra = e;
  return 0;
}

void zuregex_format_flags(uint32_t options, uint32_t extra, char *buf) {
  buf[0] = '\0';
  for (size_t k = 0; k < N_FLAGS; k++) {
    if ((flag_defs[k].options && (options & flag_defs[k].options)) ||
        (flag_defs[k].extra && (extra & flag_defs[k].extra))) {
      strcat(buf, flag_defs[k].letters);
    }
  }
}

zuregex_pattern *zuregex_pattern_compile(const zuregex_key *key, int *errcode,
                                         size_t *erroffset) {
  *errcode = 0;
  *erroffset = 0;
  // The copy is length + 1 bytes: refuse a length that would wrap.
  if (key->length >= SIZE_MAX - 1) {
    *errcode = PCRE2_ERROR_NOMEMORY;
    return NULL;
  }
  zuregex_pattern *p = calloc(1, sizeof(*p));
  char *copy = malloc(key->length + 1);
  pcre2_compile_context *ctx = pcre2_compile_context_create(NULL);
  if (p == NULL || copy == NULL || ctx == NULL) {
    free(p);
    free(copy);
    pcre2_compile_context_free(ctx);
    *errcode = PCRE2_ERROR_NOMEMORY;
    return NULL;
  }
  memcpy(copy, key->pattern, key->length);
  copy[key->length] = '\0';

  uint32_t options = key->options | (key->utf ? PCRE2_UTF : 0);
  uint32_t extra = key->extra;
  if (key->literal) {
    // The dialect's options change pattern syntax, which a literal does
    // not have, and PCRE2_LITERAL rejects them.
    options |= PCRE2_LITERAL;
  } else {
    // \C matches one byte, so in UTF mode a match could end inside a
    // character, and the next search would start there under
    // PCRE2_NO_UTF_CHECK. Bytes patterns keep it.
    if (key->utf) {
      options |= PCRE2_NEVER_BACKSLASH_C;
    } else {
      // A bytes pattern must stay bytes: (*UTF) would turn on UTF matching
      // that nothing has checked the subject for, and phase 2 would trust
      // it, as key.utf says the pattern is not UTF.
      options |= PCRE2_NEVER_UTF;
    }
    if (key->dialect == ZUREGEX_DIALECT_JS) {
      options |= JS_OPTIONS;
      extra |= JS_EXTRA;
    }
  }
  pcre2_set_compile_extra_options(ctx, extra);

  PCRE2_SIZE off = 0;
  p->code = pcre2_compile((PCRE2_SPTR) copy, key->length, options, errcode,
                          &off, ctx);
  pcre2_compile_context_free(ctx);
  if (p->code == NULL) {
    *erroffset = off;
    free(copy);
    free(p);
    return NULL;
  }
  *errcode = 0;
  if (key->jit) {
    // Failure is not an error: the interpreter runs instead, and re_info()
    // says which one this pattern uses (design section 4).
    // (*NO_JIT) makes it succeed without JIT code, so ask for the code's
    // size rather than trusting the return value.
    size_t jit_size = 0;
    p->jit_in_use =
      pcre2_jit_compile(p->code, PCRE2_JIT_COMPLETE) == 0 &&
      pcre2_pattern_info(p->code, PCRE2_INFO_JITSIZE, &jit_size) == 0 &&
      jit_size > 0;
  }
  p->refs = 1;
  p->pattern = copy;
  p->key = *key;
  p->key.pattern = copy;
  return p;
}

void zuregex_pattern_retain(zuregex_pattern *p) {
  p->refs++;
}

void zuregex_pattern_release(zuregex_pattern *p) {
  if (p == NULL || --p->refs > 0) return;
  pcre2_code_free(p->code);
  free(p->pattern);
  free(p);
}

// The C API (design section 7). No R API here: these functions run in
// consumers' code, on any thread, and in the fuzz target, which has no R.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "capi.h"
#include "pattern.h"

// zr_pattern is a compiled pattern the consumer owns; it never enters the
// R-side cache, so its reference count is the consumer's alone.
struct zr_pattern {
  zuregex_pattern *p;
};

struct zr_match_data {
  pcre2_match_data *md;
  pcre2_match_context *mctx;  // NULL until limits are set
  int pairs;                  // offset pairs the last match set
};

static const struct {
  uint32_t zr, options, extra;
} flag_map[] = {
  {ZR_CASELESS, PCRE2_CASELESS, 0},
  {ZR_MULTILINE, PCRE2_MULTILINE, 0},
  {ZR_DOTALL, PCRE2_DOTALL, 0},
  {ZR_EXTENDED, PCRE2_EXTENDED, 0},
  {ZR_EXTENDED_MORE, PCRE2_EXTENDED_MORE, 0},
  {ZR_NO_AUTO_CAPTURE, PCRE2_NO_AUTO_CAPTURE, 0},
  {ZR_UNGREEDY, PCRE2_UNGREEDY, 0},
  {ZR_DUPNAMES, PCRE2_DUPNAMES, 0},
  {ZR_UCP, PCRE2_UCP, 0},
  {ZR_CASELESS_RESTRICT, 0, PCRE2_EXTRA_CASELESS_RESTRICT},
  {ZR_ASCII_BSD, 0, PCRE2_EXTRA_ASCII_BSD},
  {ZR_ASCII_BSS, 0, PCRE2_EXTRA_ASCII_BSS},
  {ZR_ASCII_BSW, 0, PCRE2_EXTRA_ASCII_BSW},
  {ZR_ASCII_DIGIT, 0, PCRE2_EXTRA_ASCII_DIGIT},
  {ZR_ASCII_POSIX, 0, PCRE2_EXTRA_ASCII_POSIX},
};

#define KNOWN_FLAGS                                                         \
  (ZR_CASELESS | ZR_MULTILINE | ZR_DOTALL | ZR_EXTENDED | ZR_EXTENDED_MORE | \
   ZR_NO_AUTO_CAPTURE | ZR_UNGREEDY | ZR_DUPNAMES | ZR_UCP |                \
   ZR_CASELESS_RESTRICT | ZR_ASCII_BSD | ZR_ASCII_BSS | ZR_ASCII_BSW |      \
   ZR_ASCII_DIGIT | ZR_ASCII_POSIX | ZR_LITERAL | ZR_BYTES | ZR_NO_JIT)

#define ZR_STR2(x) #x
#define ZR_STR(x) ZR_STR2(x)

// A string constant, so any thread may read it at any time.
const char *zuregex_capi_version(void) {
  return "PCRE2 " ZR_STR(PCRE2_MAJOR) "." ZR_STR(PCRE2_MINOR) " " ZR_STR(PCRE2_DATE);
}

static void set_error(char *errbuf, size_t errlen, const char *msg,
                      long offset) {
  if (errbuf == NULL || errlen == 0) return;
  if (offset >= 0) {
    snprintf(errbuf, errlen, "%s at byte %ld", msg, offset);
  } else {
    snprintf(errbuf, errlen, "%s", msg);
  }
}

zr_pattern *zuregex_capi_compile(const char *pattern, size_t len,
                                 uint32_t flags, int dialect, char *errbuf,
                                 size_t errlen) {
  if (pattern == NULL && len > 0) {
    set_error(errbuf, errlen, "pattern is NULL", -1);
    return NULL;
  }
  // SIZE_MAX is PCRE2's PCRE2_ZERO_TERMINATED, which consumers pass by
  // habit: read it as a NUL-terminated pattern.
  // A NULL pattern with it was refused above.
  if (len == (size_t) -1) {
    len = strlen(pattern);
  }
  if ((flags & ~KNOWN_FLAGS) != 0 ||
      (dialect != ZR_DIALECT_PCRE && dialect != ZR_DIALECT_JS)) {
    set_error(errbuf, errlen, "unknown flags or dialect", -1);
    return NULL;
  }
  zuregex_key key;
  memset(&key, 0, sizeof(key));
  key.pattern = pattern != NULL ? pattern : "";
  key.length = len;
  for (size_t k = 0; k < sizeof(flag_map) / sizeof(flag_map[0]); k++) {
    if (flags & flag_map[k].zr) {
      key.options |= flag_map[k].options;
      key.extra |= flag_map[k].extra;
    }
  }
  key.dialect = dialect;
  key.literal = (flags & ZR_LITERAL) != 0;
  key.jit = (flags & ZR_NO_JIT) == 0;
  key.utf = (flags & ZR_BYTES) == 0;

  zr_pattern *out = malloc(sizeof(*out));
  if (out == NULL) {
    set_error(errbuf, errlen, "out of memory", -1);
    return NULL;
  }
  int errcode;
  size_t erroffset;
  out->p = zuregex_pattern_compile(&key, &errcode, &erroffset);
  if (out->p == NULL) {
    PCRE2_UCHAR msg[256];
    if (pcre2_get_error_message(errcode, msg, sizeof(msg)) < 0) {
      strcpy((char *) msg, "unknown error");
    }
    set_error(errbuf, errlen, (const char *) msg, (long) erroffset);
    free(out);
    return NULL;
  }
  return out;
}

void zuregex_capi_free(zr_pattern *p) {
  if (p == NULL) return;
  zuregex_pattern_release(p->p);
  free(p);
}

int zuregex_capi_group_count(const zr_pattern *p) {
  if (p == NULL) return ZR_ERROR_ARGUMENT;
  uint32_t n = 0;
  pcre2_pattern_info(p->p->code, PCRE2_INFO_CAPTURECOUNT, &n);
  return (int) n;
}

int zuregex_capi_group_number(const zr_pattern *p, const char *name) {
  if (p == NULL || name == NULL) return ZR_ERROR_ARGUMENT;
  int n = pcre2_substring_number_from_name(p->p->code, (PCRE2_SPTR) name);
  // A duplicated name (ZR_DUPNAMES) is PCRE2_ERROR_NOUNIQUESUBSTRING; the
  // caller gets the first group with it, as the table lists them.
  if (n == PCRE2_ERROR_NOUNIQUESUBSTRING) {
    PCRE2_SPTR first, last;
    int size = pcre2_substring_nametable_scan(p->p->code, (PCRE2_SPTR) name,
                                              &first, &last);
    if (size > 0) return ((int) first[0] << 8) | first[1];
  }
  return n > 0 ? n : ZR_ERROR_GROUP;
}

const char *zuregex_capi_group_name(const zr_pattern *p, int group) {
  if (p == NULL || group < 1) return NULL;
  uint32_t count = 0, entry_size = 0;
  PCRE2_SPTR table = NULL;
  pcre2_pattern_info(p->p->code, PCRE2_INFO_NAMECOUNT, &count);
  pcre2_pattern_info(p->p->code, PCRE2_INFO_NAMEENTRYSIZE, &entry_size);
  pcre2_pattern_info(p->p->code, PCRE2_INFO_NAMETABLE, &table);
  for (uint32_t k = 0; k < count; k++) {
    PCRE2_SPTR entry = table + (size_t) k * entry_size;
    if ((((int) entry[0] << 8) | entry[1]) == group) {
      return (const char *) entry + 2;
    }
  }
  return NULL;
}

int zuregex_capi_jit(const zr_pattern *p) {
  return p != NULL && p->p->jit_in_use;
}

zr_match_data *zuregex_capi_match_data_create(const zr_pattern *p) {
  if (p == NULL) return NULL;
  zr_match_data *md = calloc(1, sizeof(*md));
  if (md == NULL) return NULL;
  md->md = pcre2_match_data_create_from_pattern(p->p->code, NULL);
  if (md->md == NULL) {
    free(md);
    return NULL;
  }
  return md;
}

void zuregex_capi_match_data_free(zr_match_data *md) {
  if (md == NULL) return;
  pcre2_match_data_free(md->md);
  pcre2_match_context_free(md->mctx);
  free(md);
}

int zuregex_capi_set_limits(zr_match_data *md, uint32_t match,
                            uint32_t depth, uint32_t heap) {
  if (md == NULL) return ZR_ERROR_ARGUMENT;
  if (md->mctx == NULL) {
    md->mctx = pcre2_match_context_create(NULL);
    if (md->mctx == NULL) return ZR_ERROR_NOMEMORY;
  }
  // A fresh context first, so that 0 restores PCRE2's default.
  pcre2_match_context *fresh = pcre2_match_context_create(NULL);
  if (fresh == NULL) return ZR_ERROR_NOMEMORY;
  pcre2_match_context_free(md->mctx);
  md->mctx = fresh;
  if (match) pcre2_set_match_limit(md->mctx, match);
  if (depth) pcre2_set_depth_limit(md->mctx, depth);
  if (heap) pcre2_set_heap_limit(md->mctx, heap);
  return ZR_OK;
}

static int status_of(int rc) {
  switch (rc) {
  case PCRE2_ERROR_NOMATCH: return ZR_NOMATCH;
  case PCRE2_ERROR_MATCHLIMIT: return ZR_ERROR_MATCH_LIMIT;
  case PCRE2_ERROR_DEPTHLIMIT: return ZR_ERROR_DEPTH_LIMIT;
  case PCRE2_ERROR_HEAPLIMIT: return ZR_ERROR_HEAP_LIMIT;
  case PCRE2_ERROR_JIT_STACKLIMIT: return ZR_ERROR_JIT_STACK;
  case PCRE2_ERROR_NOMEMORY: return ZR_ERROR_NOMEMORY;
  case PCRE2_ERROR_NULL:
  case PCRE2_ERROR_BADOFFSET:
  case PCRE2_ERROR_BADOPTION:
  case PCRE2_ERROR_BADUTFOFFSET: return ZR_ERROR_ARGUMENT;
  case PCRE2_ERROR_BADREPLACEMENT:
  case PCRE2_ERROR_BADREPESCAPE:
  case PCRE2_ERROR_REPMISSINGBRACE:
  case PCRE2_ERROR_BADSUBSTITUTION:
  case PCRE2_ERROR_NOSUBSTRING:
  case PCRE2_ERROR_REPLACECASE: return ZR_ERROR_TEMPLATE;
  default:
    if (rc <= PCRE2_ERROR_UTF8_ERR1 && rc >= PCRE2_ERROR_UTF8_ERR21) {
      return ZR_ERROR_UTF;
    }
    return ZR_ERROR_OTHER;
  }
}

static uint32_t match_options(uint32_t options) {
  uint32_t o = 0;
  if (options & ZR_ANCHORED) o |= PCRE2_ANCHORED;
  if (options & ZR_ENDANCHORED) o |= PCRE2_ENDANCHORED;
  if (options & ZR_NOTEMPTY) o |= PCRE2_NOTEMPTY;
  if (options & ZR_NOTEMPTY_ATSTART) o |= PCRE2_NOTEMPTY_ATSTART;
  if (options & ZR_NO_JIT_MATCH) o |= PCRE2_NO_JIT;
  return o;
}

#define KNOWN_MATCH_OPTIONS                                         \
  (ZR_ANCHORED | ZR_ENDANCHORED | ZR_NOTEMPTY | ZR_NOTEMPTY_ATSTART | \
   ZR_NO_JIT_MATCH)

int zuregex_capi_match(const zr_pattern *p, const char *subject, size_t len,
                       size_t start, uint32_t options, zr_match_data *md) {
  if (p == NULL || md == NULL || (subject == NULL && len > 0) ||
      start > len || (options & ~KNOWN_MATCH_OPTIONS) != 0) {
    return ZR_ERROR_ARGUMENT;
  }
  md->pairs = 0;
  int rc = pcre2_match(p->p->code, (PCRE2_SPTR) (subject ? subject : ""), len,
                       start, match_options(options), md->md, md->mctx);
  if (rc == 0) {
    // The match data has fewer pairs than the pattern has groups: it was
    // made for another pattern. The pairs it has are set.
    rc = (int) pcre2_get_ovector_count(md->md);
  }
  if (rc < 0) return status_of(rc);
  md->pairs = rc;
  return rc;
}

int zuregex_capi_offsets(const zr_match_data *md, int group, size_t *start,
                         size_t *end) {
  if (md == NULL || start == NULL || end == NULL) return ZR_ERROR_ARGUMENT;
  if (group < 0 || (uint32_t) group >= pcre2_get_ovector_count(md->md)) {
    return ZR_ERROR_GROUP;
  }
  if (group >= md->pairs) return ZR_NOMATCH;
  PCRE2_SIZE *ov = pcre2_get_ovector_pointer(md->md);
  if (ov[2 * group] == PCRE2_UNSET) return ZR_NOMATCH;
  *start = ov[2 * group];
  *end = ov[2 * group + 1];
  return ZR_OK;
}

int zuregex_capi_substitute(const zr_pattern *p, const char *subject,
                            size_t len, const char *tmpl, size_t tlen,
                            uint32_t options, zr_match_data *md, char *out,
                            size_t *outlen) {
  if (p == NULL || outlen == NULL || (subject == NULL && len > 0) ||
      (tmpl == NULL && tlen > 0) || (out == NULL && *outlen > 0) ||
      (options & ~(ZR_SUBSTITUTE_GLOBAL | ZR_SUBSTITUTE_LITERAL)) != 0) {
    return ZR_ERROR_ARGUMENT;
  }
  uint32_t o = PCRE2_SUBSTITUTE_UNSET_EMPTY | PCRE2_SUBSTITUTE_OVERFLOW_LENGTH;
  o |= (options & ZR_SUBSTITUTE_LITERAL) ? PCRE2_SUBSTITUTE_LITERAL
                                         : PCRE2_SUBSTITUTE_EXTENDED;
  if (options & ZR_SUBSTITUTE_GLOBAL) o |= PCRE2_SUBSTITUTE_GLOBAL;
  char empty[1];
  PCRE2_SIZE size = *outlen;
  int rc = pcre2_substitute(p->p->code, (PCRE2_SPTR) (subject ? subject : ""),
                            len, 0, o, md != NULL ? md->md : NULL,
                            md != NULL ? md->mctx : NULL,
                            (PCRE2_SPTR) (tmpl ? tmpl : ""), tlen,
                            (PCRE2_UCHAR *) (out != NULL ? out : empty), &size);
  if (md != NULL) md->pairs = 0;
  if (rc >= 0) {
    *outlen = size;
    return rc;
  }
  if (rc == PCRE2_ERROR_NOMEMORY) *outlen = size;
  return status_of(rc);
}

const char *zuregex_capi_strerror(int code) {
  if (code >= 0) return "no error";
  switch (code) {
  case ZR_NOMATCH: return "no match";
  // The limit messages are PCRE2's own, which callers may already show.
  case ZR_ERROR_MATCH_LIMIT: return "match limit exceeded";
  case ZR_ERROR_DEPTH_LIMIT: return "matching depth limit exceeded";
  case ZR_ERROR_HEAP_LIMIT: return "heap limit exceeded";
  case ZR_ERROR_JIT_STACK: return "JIT stack limit reached";
  case ZR_ERROR_UTF: return "the subject is not valid UTF-8";
  case ZR_ERROR_NOMEMORY: return "out of memory, or the output buffer is too small";
  case ZR_ERROR_ARGUMENT: return "invalid argument";
  case ZR_ERROR_TEMPLATE: return "malformed substitution template";
  case ZR_ERROR_GROUP: return "no such group";
  default: return "PCRE2 error";
  }
}

// libFuzzer target for the C API: zr_compile(), zr_match() over every
// match, and zr_substitute(). Each input is matched with JIT code and
// without, and any difference in status or offsets traps: a wrong result
// in one engine, which a crash oracle alone would never see (#136). Built without R by .github/workflows/
// fuzz.yaml from src/capi.c, src/pattern.c and the vendored PCRE2.
//
// Input layout: byte 0 picks flags, byte 1 the dialect and match options,
// byte 2 the pattern's length (mod the rest); the pattern follows, and the
// subject is everything after it. Short inputs are ignored.

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "../../src/capi.h"

static const uint32_t flag_choices[] = {
  0, ZR_CASELESS, ZR_MULTILINE | ZR_DOTALL, ZR_EXTENDED, ZR_UCP,
  ZR_LITERAL, ZR_BYTES, ZR_NO_JIT, ZR_CASELESS | ZR_UCP | ZR_ASCII_BSW,
  ZR_EXTENDED_MORE | ZR_DUPNAMES, ZR_UNGREEDY | ZR_NO_AUTO_CAPTURE,
  ZR_BYTES | ZR_NO_JIT | ZR_CASELESS,
};

static int is_limit(int rc) {
  return rc == ZR_ERROR_MATCH_LIMIT || rc == ZR_ERROR_DEPTH_LIMIT ||
         rc == ZR_ERROR_HEAP_LIMIT || rc == ZR_ERROR_JIT_STACK;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size < 3) return 0;
  uint32_t flags = flag_choices[data[0] % (sizeof(flag_choices) / sizeof(flag_choices[0]))];
  int dialect = data[1] & 1;
  uint32_t mopts = (data[1] >> 1) & (ZR_ANCHORED | ZR_ENDANCHORED | ZR_NOTEMPTY);
  size_t rest = size - 3;
  size_t plen = rest ? data[2] % (rest + 1) : 0;
  const char *pattern = (const char *) data + 3;
  const char *subject = pattern + plen;
  size_t slen = rest - plen;

  char err[128];
  zr_pattern *p = zuregex_capi_compile(pattern, plen, flags, dialect, err, sizeof(err));
  // The same pattern without JIT code: every result must agree (#136).
  zr_pattern *q = zuregex_capi_compile(pattern, plen, flags | ZR_NO_JIT, dialect,
                                       err, sizeof(err));
  if ((p == NULL) != (q == NULL)) __builtin_trap();
  if (p == NULL) return 0;
  zr_match_data *md = zuregex_capi_match_data_create(p);
  zr_match_data *mq = zuregex_capi_match_data_create(q);
  if (md != NULL && mq != NULL) {
    zuregex_capi_set_limits(md, 100000, 1000, 1024);
    zuregex_capi_set_limits(mq, 100000, 1000, 1024);
    int groups = zuregex_capi_group_count(p);
    int utf = !(flags & ZR_BYTES);
    size_t start = 0;
    for (int k = 0; k < 64 && start <= slen; k++) {
      int rc = zuregex_capi_match(p, subject, slen, start, mopts, md);
      int rq = zuregex_capi_match(q, subject, slen, start, mopts, mq);
      // The engines count work differently, so a limit may stop one only.
      if (is_limit(rc) || is_limit(rq)) break;
      if (rc != rq) __builtin_trap();
      if (rc < 0) break;
      size_t b = start;
      for (int g = 0; g <= groups; g++) {
        size_t a1 = 0, b1 = 0, a2 = 0, b2 = 0;
        int o1 = zuregex_capi_offsets(md, g, &a1, &b1);
        int o2 = zuregex_capi_offsets(mq, g, &a2, &b2);
        if (o1 != o2 || (o1 == ZR_OK && (a1 != a2 || b1 != b2))) __builtin_trap();
        if (g == 0 && o1 == ZR_OK) b = b1;
      }
      // After an empty match, step one character, not one byte: a start
      // inside a UTF-8 character is an argument error, which ended the
      // loop on every non-ASCII subject before (#180).
      if (b > start) {
        start = b;
      } else {
        start++;
        while (utf && start < slen && ((unsigned char) subject[start] & 0xC0) == 0x80) {
          start++;
        }
      }
    }
    char out[256];
    size_t outlen = sizeof(out);
    zuregex_capi_substitute(p, subject, slen, "<$0>${1:-x}", 11,
                            ZR_SUBSTITUTE_GLOBAL, md, out, &outlen);
  }
  zuregex_capi_match_data_free(md);
  zuregex_capi_match_data_free(mq);
  for (int g = 0; g <= 3; g++) zuregex_capi_group_name(p, g);
  zuregex_capi_group_number(p, "name");
  zuregex_capi_free(p);
  zuregex_capi_free(q);
  return 0;
}

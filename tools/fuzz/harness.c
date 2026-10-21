// libFuzzer target for the C API: zr_compile(), zr_match() over every
// match, and zr_substitute(). Built without R by .github/workflows/
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
  if (p == NULL) return 0;
  zr_match_data *md = zuregex_capi_match_data_create(p);
  if (md != NULL) {
    zuregex_capi_set_limits(md, 100000, 1000, 1024);
    int groups = zuregex_capi_group_count(p);
    size_t start = 0;
    for (int k = 0; k < 64 && start <= slen; k++) {
      int rc = zuregex_capi_match(p, subject, slen, start, mopts, md);
      if (rc < 0) break;
      size_t a = 0, b = 0;
      for (int g = 0; g <= groups; g++) {
        zuregex_capi_offsets(md, g, &a, &b);
      }
      zuregex_capi_offsets(md, 0, &a, &b);
      start = b > start ? b : start + 1;
    }
    char out[256];
    size_t outlen = sizeof(out);
    zuregex_capi_substitute(p, subject, slen, "<$0>${1:-x}", 11,
                            ZR_SUBSTITUTE_GLOBAL, md, out, &outlen);
    zuregex_capi_match_data_free(md);
  }
  for (int g = 0; g <= 3; g++) zuregex_capi_group_name(p, g);
  zuregex_capi_group_number(p, "name");
  zuregex_capi_free(p);
  return 0;
}

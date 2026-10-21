#ifndef ZUREGEX_CAPI_H
#define ZUREGEX_CAPI_H

// The C API's implementation (capi.c), without R: init.c puts these in the
// registered table, and the fuzz harness calls them directly.

#include "../inst/include/zuregex.h"

const char *zuregex_capi_version(void);
zr_pattern *zuregex_capi_compile(const char *pattern, size_t len,
                                 uint32_t flags, int dialect, char *errbuf,
                                 size_t errlen);
void zuregex_capi_free(zr_pattern *p);
int zuregex_capi_group_count(const zr_pattern *p);
int zuregex_capi_group_number(const zr_pattern *p, const char *name);
const char *zuregex_capi_group_name(const zr_pattern *p, int group);
int zuregex_capi_jit(const zr_pattern *p);
zr_match_data *zuregex_capi_match_data_create(const zr_pattern *p);
void zuregex_capi_match_data_free(zr_match_data *md);
int zuregex_capi_set_limits(zr_match_data *md, uint32_t match,
                            uint32_t depth, uint32_t heap);
int zuregex_capi_match(const zr_pattern *p, const char *subject, size_t len,
                       size_t start, uint32_t options, zr_match_data *md);
int zuregex_capi_offsets(const zr_match_data *md, int group, size_t *start,
                         size_t *end);
int zuregex_capi_substitute(const zr_pattern *p, const char *subject,
                            size_t len, const char *tmpl, size_t tlen,
                            uint32_t options, zr_match_data *md, char *out,
                            size_t *outlen);
const char *zuregex_capi_strerror(int code);

#endif

/* zuregex's C API for R packages.
 *
 * Include this in a package that uses zuregex from C. It adds to
 * <zuregex.h> the one thing that knows about R: how to get zuregex's
 * function table, which zuregex registers with R_RegisterCCallable(). Then
 * call the zr_*() functions below.
 *
 *     #include <zuregex-r.h>
 *
 *     char err[256];
 *     zr_pattern *p = zr_compile("(\\d+)-(\\d+)", 12, 0, ZR_DIALECT_PCRE,
 *                                err, sizeof err);
 *     zr_match_data *md = zr_match_data_create(p);
 *     if (zr_match(p, "a 12-34", 7, 0, 0, md) > 0) {
 *       size_t s, e;
 *       zr_offsets(md, 1, &s, &e);   // s == 2, e == 4
 *     }
 *     zr_match_data_free(md);
 *     zr_free(p);
 *
 * DESCRIPTION needs both
 *
 *     Imports:   zuregex     # loads zuregex, which registers the table
 *     LinkingTo: zuregex     # provides these headers
 *
 * and NAMESPACE a real import, such as importFrom(zuregex, zuregex_info):
 * Imports alone does not load zuregex before your code runs.
 *
 * The table is versioned. Fields are only ever appended; a change to an
 * existing one gets a new callable name (zuregex_api_v2), so an old
 * consumer fails at R_GetCCallable() instead of calling the wrong thing.
 *
 * Copyright (c) 2026 Pedro Baltazar. MIT licence; see the LICENSE file.
 */

#ifndef ZUREGEX_R_H
#define ZUREGEX_R_H

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#include "zuregex.h"

#ifdef __cplusplus
extern "C" {
#endif

#define ZUREGEX_API_VERSION 1

typedef struct {
  int abi_version;    /* ZUREGEX_API_VERSION of the provider */
  size_t struct_size; /* sizeof the provider's table */
  zr_version_fn version;
  zr_compile_fn compile;
  zr_free_fn free;
  zr_group_count_fn group_count;
  zr_group_number_fn group_number;
  zr_group_name_fn group_name;
  zr_jit_fn jit;
  zr_match_data_create_fn match_data_create;
  zr_match_data_free_fn match_data_free;
  zr_set_limits_fn set_limits;
  zr_match_fn match;
  zr_offsets_fn offsets;
  zr_substitute_fn substitute;
  zr_strerror_fn strerror;
} zuregex_api_v1;

/* The table, looked up once. Raises an R error if zuregex is not loaded
 * or implements a different version, so call it from R-facing code first
 * (your R_init_ or the .Call entry), not from a worker thread. */
static inline const zuregex_api_v1 *zuregex_api(void) {
  static const zuregex_api_v1 *api = NULL;
  if (api == NULL) {
    const zuregex_api_v1 *(*get)(void) =
      (const zuregex_api_v1 *(*)(void)) R_GetCCallable("zuregex", "zuregex_api_v1");
    const zuregex_api_v1 *table = get();
    if (table == NULL || table->abi_version != ZUREGEX_API_VERSION ||
        table->struct_size < sizeof(zuregex_api_v1)) {
      Rf_error("zuregex does not provide C API version %d; reinstall it",
               ZUREGEX_API_VERSION);
    }
    api = table;
  }
  return api;
}

static inline const char *zr_version(void) {
  return zuregex_api()->version();
}
static inline zr_pattern *zr_compile(const char *pattern, size_t len,
                                     uint32_t flags, int dialect,
                                     char *errbuf, size_t errlen) {
  return zuregex_api()->compile(pattern, len, flags, dialect, errbuf, errlen);
}
static inline void zr_free(zr_pattern *p) {
  zuregex_api()->free(p);
}
static inline int zr_group_count(const zr_pattern *p) {
  return zuregex_api()->group_count(p);
}
static inline int zr_group_number(const zr_pattern *p, const char *name) {
  return zuregex_api()->group_number(p, name);
}
static inline const char *zr_group_name(const zr_pattern *p, int group) {
  return zuregex_api()->group_name(p, group);
}
static inline int zr_jit(const zr_pattern *p) {
  return zuregex_api()->jit(p);
}
static inline zr_match_data *zr_match_data_create(const zr_pattern *p) {
  return zuregex_api()->match_data_create(p);
}
static inline void zr_match_data_free(zr_match_data *md) {
  zuregex_api()->match_data_free(md);
}
static inline int zr_set_limits(zr_match_data *md, uint32_t match,
                                uint32_t depth, uint32_t heap) {
  return zuregex_api()->set_limits(md, match, depth, heap);
}
static inline int zr_match(const zr_pattern *p, const char *subject,
                           size_t len, size_t start, uint32_t options,
                           zr_match_data *md) {
  return zuregex_api()->match(p, subject, len, start, options, md);
}
static inline int zr_offsets(const zr_match_data *md, int group,
                             size_t *start, size_t *end) {
  return zuregex_api()->offsets(md, group, start, end);
}
static inline int zr_substitute(const zr_pattern *p, const char *subject,
                                size_t len, const char *tmpl, size_t tlen,
                                uint32_t options, zr_match_data *md,
                                char *out, size_t *outlen) {
  return zuregex_api()->substitute(p, subject, len, tmpl, tlen, options, md,
                                   out, outlen);
}
static inline const char *zr_strerror(int code) {
  return zuregex_api()->strerror(code);
}

#ifdef __cplusplus
}
#endif

#endif /* ZUREGEX_R_H */

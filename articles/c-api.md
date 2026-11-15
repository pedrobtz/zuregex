# Link to zuregex from C

This guide is for the author of an R package whose C or C++ code needs
regular expressions. It shows how to depend on zuregex in place of
bundling PCRE2, and how to compile, match, read groups and substitute
with the `zr_*()` functions. It assumes you have written `.Call` code
before.

## Declare the dependency

The package needs zuregex twice in `DESCRIPTION`: `LinkingTo` provides
the headers, and `Imports` loads zuregex, which is what registers its
functions.

    Imports: zuregex
    LinkingTo: zuregex

`Imports` alone does not load zuregex before your code runs. `NAMESPACE`
needs a real import as well, of any function:

    importFrom(zuregex, zuregex_info)

Nothing is added to `src/Makevars`. The functions are found when the
package is loaded, not when it is linked, so your package holds no copy
of PCRE2.

## Compile and match

Include `<zuregex-r.h>`. A pattern is a `zr_pattern`, and the offsets of
a match go into a `zr_match_data` made for that pattern. `zr_match()`
returns a positive number when it finds a match, and `ZR_NOMATCH` when
it does not. This `.Call` routine returns whether a string matches a
pattern.

``` c
#include <string.h>
#include <R.h>
#include <Rinternals.h>
#include <zuregex-r.h>

SEXP has_match(SEXP pattern, SEXP x) {
  const char *pat = Rf_translateCharUTF8(STRING_ELT(pattern, 0));
  const char *s = Rf_translateCharUTF8(STRING_ELT(x, 0));

  char err[256];
  zr_pattern *p = zr_compile(pat, strlen(pat), 0, ZR_DIALECT_PCRE,
                             err, sizeof(err));
  if (p == NULL) Rf_error("%s", err);

  zr_match_data *md = zr_match_data_create(p);
  int rc = zr_match(p, s, strlen(s), 0, 0, md);

  zr_match_data_free(md);
  zr_free(p);
  return Rf_ScalarLogical(rc > 0);
}
```

The third argument of `zr_compile()` takes the flags of
[`re_compile()`](https://pedrobtz.github.io/zuregex/reference/re_compile.md)
in bit form, such as `ZR_CASELESS` for `i`. When compiling fails, it
returns `NULL` and writes a message into `err`.

## Read the groups

After a match, `zr_offsets()` gives where a group starts and ends. Group
0 is the whole match, and `zr_group_number()` turns a name into a
number.

``` c
size_t start, end;
if (zr_offsets(md, 1, &start, &end) == ZR_OK) {
  /* group 1 is the bytes s[start] to s[end - 1] */
}
```

The offsets are not the ones the R functions return. In C they are
zero-based, half-open and in bytes;
[`re_locate()`](https://pedrobtz.github.io/zuregex/reference/re_locate.md)
gives one-based, inclusive offsets in characters. Convert when a result
goes back to R.

## Substitute

`zr_substitute()` writes the subject with its matches replaced into a
buffer you supply. `size` holds the size of the buffer going in and the
length of the result coming out. If the buffer is too small, the call
returns `ZR_ERROR_NOMEMORY` and sets `size` to what it needs, so try
again with that.

``` c
size_t size = 256;
char *out = R_alloc(size, 1);
int rc = zr_substitute(p, s, strlen(s), tmpl, strlen(tmpl),
                       ZR_SUBSTITUTE_GLOBAL, NULL, out, &size);
if (rc == ZR_ERROR_NOMEMORY) {
  out = R_alloc(size, 1);
  rc = zr_substitute(p, s, strlen(s), tmpl, strlen(tmpl),
                     ZR_SUBSTITUTE_GLOBAL, NULL, out, &size);
}
if (rc < 0) Rf_error("%s", zr_strerror(rc));
```

The template has the syntax of
[`re_replace()`](https://pedrobtz.github.io/zuregex/reference/re_replace.md).
Without `ZR_SUBSTITUTE_GLOBAL` only the first match is replaced.

## Limits and threads

`zr_set_limits(md, match, depth, heap)` bounds every match run with that
match data, as
[`re_limits()`](https://pedrobtz.github.io/zuregex/reference/re_limits.md)
does in R; a search that hits one returns `ZR_ERROR_MATCH_LIMIT`,
`ZR_ERROR_DEPTH_LIMIT` or `ZR_ERROR_HEAP_LIMIT`.

No `zr_*()` function raises an R error or allocates an R object, so they
can run on worker threads under two rules. A compiled pattern may be
shared between threads, but each thread needs its own `zr_match_data`.
And in each C file that calls `zr_*()` from a worker thread, call
`zuregex_api()` once on the main thread first, since the first call
looks the functions up through R.

## What stays stable

Patterns and match data are opaque handles, and the headers name no
PCRE2 type. An upgrade of the PCRE2 inside zuregex therefore never
changes your build. The function table is versioned and only grows: a
package built against an older zuregex keeps working with a newer one.

## See also

The two headers are the reference for the C API:
[`zuregex.h`](https://github.com/pedrobtz/zuregex/blob/main/inst/include/zuregex.h)
has every flag, option and status code, and
[`zuregex-r.h`](https://github.com/pedrobtz/zuregex/blob/main/inst/include/zuregex-r.h)
the `zr_*()` functions. For limits on the R side, read [Bound the work
of a match](https://pedrobtz.github.io/zuregex/articles/limits.html).

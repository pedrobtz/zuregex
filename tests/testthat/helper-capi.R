# The C API as a consumer sees it, through internal .Call entry points that
# use <zuregex-r.h> and so R_GetCCallable() (src/capi_test.c).

# Flag and option values from inst/include/zuregex.h.
zr <- function() {
  list(
    CASELESS = 0x1,
    MULTILINE = 0x2,
    DOTALL = 0x4,
    UCP = 0x100,
    LITERAL = 0x10000,
    BYTES = 0x20000,
    NO_JIT = 0x40000,
    ANCHORED = 0x1L,
    ENDANCHORED = 0x2L,
    NOTEMPTY = 0x4L,
    GLOBAL = 0x1L,
    SUB_LITERAL = 0x2L,
    NOMATCH = -1L,
    ERROR_MATCH_LIMIT = -2L,
    ERROR_UTF = -3L,
    ERROR_NOMEMORY = -4L,
    ERROR_ARGUMENT = -5L,
    ERROR_TEMPLATE = -6L,
    ERROR_GROUP = -7L,
    ERROR_DEPTH_LIMIT = -9L,
    ERROR_HEAP_LIMIT = -10L,
    ERROR_JIT_STACK = -11L
  )
}

capi_match <- function(
  pattern,
  subjects,
  flags = 0,
  dialect = 0L,
  options = 0L,
  start = 0
) {
  .Call(
    zuregex:::zuregex_capi_match_c,
    pattern,
    as.double(flags),
    dialect,
    subjects,
    options,
    as.double(start)
  )
}

capi_substitute <- function(
  pattern,
  subject,
  template,
  options = 0L,
  flags = 0,
  bufsize = 256
) {
  .Call(
    zuregex:::zuregex_capi_substitute_c,
    pattern,
    as.double(flags),
    0L,
    subject,
    template,
    options,
    as.double(bufsize)
  )
}

capi_info <- function(pattern, name = "x", flags = 0) {
  .Call(zuregex:::zuregex_capi_info_c, pattern, as.double(flags), 0L, name)
}

// zuregex_info(): what the vendored PCRE2 was built with, and whether its
// JIT compiler works on this machine.

#include <string.h>

#include "zuregex.h"
#include "pcre2.h"

// A pcre2_config() string, or NA when the option is unknown.
static SEXP config_string(uint32_t what) {
  char buf[128];
  int n = pcre2_config(what, NULL);
  if (n <= 0 || (size_t) n > sizeof(buf)) {
    return Rf_ScalarString(NA_STRING);
  }
  pcre2_config(what, buf);
  return Rf_mkString(buf);
}

static int config_flag(uint32_t what) {
  uint32_t value = 0;
  if (pcre2_config(what, &value) < 0) {
    return 0;
  }
  return value != 0;
}

// The JIT can be compiled in and still fail at run time: on a CPU sljit does
// not support, or where the system refuses executable memory (SELinux
// policies, hardened macOS runtimes). PCRE2 then falls back to the
// interpreter without saying so (design section 4), so this asks it to JIT
// compile a pattern and reports whether that worked.
static int jit_usable(void) {
  if (!config_flag(PCRE2_CONFIG_JIT)) {
    return 0;
  }
  int errcode;
  PCRE2_SIZE erroffset;
  pcre2_code *code = pcre2_compile(
    (PCRE2_SPTR) "a+b", PCRE2_ZERO_TERMINATED, 0, &errcode, &erroffset, NULL
  );
  if (code == NULL) {
    return 0;
  }
  int ok = pcre2_jit_compile(code, PCRE2_JIT_COMPLETE) == 0;
  pcre2_code_free(code);
  return ok;
}

SEXP zuregex_info_c(void) {
  const char *names[] = {
    "pcre2_version", "unicode", "unicode_version", "jit", "jit_usable",
    "jit_target", ""
  };
  int usable = jit_usable();
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(out, 0, config_string(PCRE2_CONFIG_VERSION));
  SET_VECTOR_ELT(out, 1, Rf_ScalarLogical(config_flag(PCRE2_CONFIG_UNICODE)));
  SET_VECTOR_ELT(out, 2, config_string(PCRE2_CONFIG_UNICODE_VERSION));
  SET_VECTOR_ELT(out, 3, Rf_ScalarLogical(config_flag(PCRE2_CONFIG_JIT)));
  SET_VECTOR_ELT(out, 4, Rf_ScalarLogical(usable));
  SET_VECTOR_ELT(out, 5, config_string(PCRE2_CONFIG_JITTARGET));
  UNPROTECT(1);
  return out;
}

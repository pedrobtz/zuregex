#!/bin/sh
# Build the C core (capi.c pattern.c + PCRE2) with ASan+UBSan into libcore.a
S=/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz-zuregex/e53874e6-da4a-401d-a173-3b05192b4f61/scratchpad/hunt/src
W=/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz-zuregex/e53874e6-da4a-401d-a173-3b05192b4f61/scratchpad/hunt/hunt-3
mkdir -p $W/obj && cd $W/obj
FLAGS="-g -O1 -fsanitize=address,undefined -fno-omit-frame-pointer -I$S/src/pcre2-config -I$S/src/vendor/pcre2/src -DHAVE_CONFIG_H -DPCRE2_CODE_UNIT_WIDTH=8 -DPCRE2_STATIC"
for f in $S/src/capi.c $S/src/pattern.c $(ls $S/src/vendor/pcre2/src/pcre2_*.c | grep -v -e fuzzsupport -e dftables -e printint -e jit_match -e jit_misc -e jit_test -e ucptables -e pcre2test -e _inc); do
  clang $FLAGS -c $f -o $(basename $f .c).o || echo FAIL $f
done
ar rcs $W/libcore.a *.o

// Probe 2: zr_substitute contract, buffer straddles, sequences
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "capi.h"
#define C zuregex_capi_compile
#define SUB zuregex_capi_substitute
#define SHOW(x) printf("%-60s = %d\n", #x, (int)(x))
static void dump(const char *tag, const char *b, size_t n){printf("%s [",tag);for(size_t i=0;i<n;i++)printf(b[i]>=32&&b[i]<127?"%c":"\\x%02x",(unsigned char)b[i]);printf("]\n");}
int main(void){
  char err[256];
  zr_pattern*p=C("(\\d+)",(size_t)-1,0,0,err,sizeof err);
  // result is "a<12>b<3>" = 9 bytes
  for(size_t cap=0; cap<=11; cap++){
    char *out=malloc(cap?cap:1); memset(out,'#',cap); size_t n=cap;
    int rc=SUB(p,"a12b3",5,"<$1>",4,ZR_SUBSTITUTE_GLOBAL,NULL,out,&n);
    printf("cap=%2zu rc=%d outlen=%zu ",cap,rc,n); dump("out",out,cap); free(out);
  }
  { size_t n=0; int rc=SUB(p,"a12b3",5,"<$1>",4,ZR_SUBSTITUTE_GLOBAL,NULL,NULL,&n); printf("NULL out, 0: rc=%d outlen=%zu\n",rc,n);}
  { size_t n=5; int rc=SUB(p,"a12b3",5,"<$1>",4,ZR_SUBSTITUTE_GLOBAL,NULL,NULL,&n); printf("NULL out, 5: rc=%d outlen=%zu\n",rc,n);}
  { char out[64]; int rc=SUB(p,"a12b3",5,"<$1>",4,ZR_SUBSTITUTE_GLOBAL,NULL,out,NULL); printf("NULL outlen rc=%d\n",rc);}
  // first only / no match
  { char out[64]; memset(out,'#',64); size_t n=64; int rc=SUB(p,"a12b3",5,"<$1>",4,0,NULL,out,&n); printf("first: rc=%d outlen=%zu %.*s\n",rc,n,(int)n,out);}
  { char out[64]; memset(out,'#',64); size_t n=64; int rc=SUB(p,"abc",3,"<$1>",4,0,NULL,out,&n); printf("nomatch: rc=%d outlen=%zu ",rc,n); dump("out",out,6);}
  { char out[2]; memset(out,'#',2); size_t n=2; int rc=SUB(p,"abc",3,"<$1>",4,0,NULL,out,&n); printf("nomatch small buf: rc=%d outlen=%zu ",rc,n); dump("out",out,2);}
  // template errors: outlen after
  { const char*t[]={"$","${","$9","${zz}","\\","\\U$1","${1:-x","$1$","\\x{110000}","\\Q","$*MARK","${1:+a:b}","\\N{U+41}","$0"};
    for(int i=0;i<14;i++){char out[64]; memset(out,'#',64); size_t n=64; int rc=SUB(p,"a12b3",5,t[i],strlen(t[i]),ZR_SUBSTITUTE_GLOBAL,NULL,out,&n); printf("tmpl %-12s rc=%d outlen=%zu ",t[i],rc,n); dump("out",out,12);} }
  // literal option
  { char out[64]; size_t n=64; int rc=SUB(p,"a12b3",5,"<$1>",4,ZR_SUBSTITUTE_GLOBAL|ZR_SUBSTITUTE_LITERAL,NULL,out,&n); printf("literal: rc=%d %.*s\n",rc,(int)n,out);}
  { char out[64]; size_t n=64; SHOW(SUB(p,"a",1,"x",1,4,NULL,out,&n)); SHOW(SUB(NULL,"a",1,"x",1,0,NULL,out,&n)); SHOW(SUB(p,NULL,1,"x",1,0,NULL,out,&n)); SHOW(SUB(p,"a",1,NULL,1,0,NULL,out,&n)); n=64; int rc=SUB(p,"1",1,NULL,0,0,NULL,out,&n); printf("NULL tmpl len0 rc=%d n=%zu\n",rc,n); n=64; rc=SUB(p,NULL,0,"x",1,0,NULL,out,&n); printf("NULL subj len0 rc=%d n=%zu\n",rc,n);}
  // SIZE_MAX lengths
  { char out[64]; size_t n=64; int rc=SUB(p,"a12b3",(size_t)-1,"<$1>",(size_t)-1,ZR_SUBSTITUTE_GLOBAL,NULL,out,&n); printf("SIZE_MAX lens: rc=%d n=%zu %.*s\n",rc,n,rc>=0?(int)n:0,out);}
  // invalid UTF subject / template
  { char out[64]; size_t n=64; int rc=SUB(p,"a\xff""1",3,"x",1,0,NULL,out,&n); printf("bad utf subj rc=%d n=%zu\n",rc,n); n=64; rc=SUB(p,"a1",2,"\xff",1,0,NULL,out,&n); printf("bad utf tmpl rc=%d n=%zu\n",rc,n);}
  // empty-match global
  { zr_pattern*q=C("x*",(size_t)-1,0,0,err,sizeof err); char out[64]; size_t n=64; int rc=SUB(q,"abc",3,"-",1,ZR_SUBSTITUTE_GLOBAL,NULL,out,&n); printf("x* global: rc=%d %.*s\n",rc,(int)n,out); zuregex_capi_free(q);}
  // with md: sequences
  { zr_match_data*md=zuregex_capi_match_data_create(p); size_t s=7,e=7; char out[64]; size_t n=64;
    SHOW(zuregex_capi_match(p,"a12b3",5,0,0,md));
    int rc=SUB(p,"zz99",4,"<$1>",4,ZR_SUBSTITUTE_GLOBAL,md,out,&n); printf("sub with md rc=%d %.*s\n",rc,(int)n,out);
    SHOW(zuregex_capi_offsets(md,0,&s,&e)); SHOW(zuregex_capi_offsets(md,1,&s,&e));
    SHOW(zuregex_capi_match(p,"a12b3",5,0,0,md)); SHOW(zuregex_capi_offsets(md,1,&s,&e)); printf("s=%zu e=%zu\n",s,e);
    // limits
    SHOW(zuregex_capi_set_limits(md,1,0,0)); 
    zr_pattern*q=C("(a+)+$",(size_t)-1,ZR_NO_JIT,0,err,sizeof err); zr_pattern*qj=C("(a+)+$",(size_t)-1,0,0,err,sizeof err);
    SHOW(zuregex_capi_jit(q)); SHOW(zuregex_capi_jit(qj));
    SHOW(zuregex_capi_match(q,"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab",32,0,0,md));
    SHOW(zuregex_capi_match(qj,"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab",32,0,0,md));
    n=64; rc=SUB(q,"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab",32,"x",1,0,md,out,&n); printf("sub under match limit rc=%d n=%zu\n",rc,n);
    SHOW(zuregex_capi_set_limits(md,0,0,0));
    SHOW(zuregex_capi_match(q,"aaaaaaaaaaaaab",14,0,0,md));
    SHOW(zuregex_capi_set_limits(md,0,1,0)); SHOW(zuregex_capi_match(q,"aaaaaaaaaaaaab",14,0,0,md)); SHOW(zuregex_capi_match(qj,"aaaaaaaaaaaaab",14,0,0,md));
    SHOW(zuregex_capi_set_limits(md,0,0,1)); SHOW(zuregex_capi_match(q,"aaaaaaaaaaaaab",14,0,0,md));
    SHOW(zuregex_capi_set_limits(md,0xffffffffu,0xffffffffu,0xffffffffu)); SHOW(zuregex_capi_match(q,"aaaaaaaaaaaaab",14,0,0,md));
    SHOW(zuregex_capi_set_limits(md,0,0,0)); SHOW(zuregex_capi_match(q,"aaaaaaaaaaaaab",14,0,0,md));
    // heap limit with big backtracking
    { zr_pattern*h=C("(?:(?:a|b)*)*c",(size_t)-1,ZR_NO_JIT,0,err,sizeof err); char *big=malloc(200000); memset(big,'a',200000); SHOW(zuregex_capi_set_limits(md,0,0,1)); SHOW(zuregex_capi_match(h,big,200000,0,0,md)); SHOW(zuregex_capi_set_limits(md,0,0,0)); free(big); zuregex_capi_free(h);}
    // pattern (*LIMIT_MATCH=) raising? 
    { zr_pattern*h=C("(*LIMIT_MATCH=1)(a+)+$",(size_t)-1,ZR_NO_JIT,0,err,sizeof err); SHOW(zuregex_capi_match(h,"aaaaaaaaaaaaab",14,0,0,md)); zuregex_capi_free(h);}
    // match data from pattern with 1 group used with pattern with 5 groups
    zr_pattern*g5=C("(a)(b)(c)(d)(e)",(size_t)-1,0,0,err,sizeof err); zr_pattern*g5n=C("(a)(b)(c)(d)(e)",(size_t)-1,ZR_NO_JIT,0,err,sizeof err);
    rc=zuregex_capi_match(g5,"abcde",5,0,0,md); printf("small md, 5 groups (jit): rc=%d\n",rc); for(int g=0;g<=6;g++){s=e=77; int r=zuregex_capi_offsets(md,g,&s,&e); printf("  offsets(%d)=%d s=%zu e=%zu\n",g,r,s,e);}
    rc=zuregex_capi_match(g5n,"abcde",5,0,0,md); printf("small md, 5 groups (nojit): rc=%d\n",rc); for(int g=0;g<=2;g++){s=e=77; int r=zuregex_capi_offsets(md,g,&s,&e); printf("  offsets(%d)=%d s=%zu e=%zu\n",g,r,s,e);}
    n=64; rc=SUB(g5,"abcde",5,"[$5$1]",6,0,md,out,&n); printf("sub small md tmpl $5: rc=%d n=%zu %.*s\n",rc,n,rc>=0?(int)n:0,out);
    n=64; rc=SUB(g5,"abcde",5,"[$1]",4,0,md,out,&n); printf("sub small md tmpl $1: rc=%d n=%zu %.*s\n",rc,n,rc>=0?(int)n:0,out);
    n=64; rc=SUB(g5,"abcde",5,"[$5$1]",6,0,NULL,out,&n); printf("sub NULL md tmpl $5: rc=%d n=%zu %.*s\n",rc,n,rc>=0?(int)n:0,out);
    // backreference pattern with small md
    { zr_pattern*b=C("(a)(b)(c)\\3\\2\\1",(size_t)-1,ZR_NO_JIT,0,err,sizeof err); zr_pattern*z=C("x",1,0,0,err,sizeof err); zr_match_data*m0=zuregex_capi_match_data_create(z); rc=zuregex_capi_match(b,"abccba",6,0,0,m0); printf("backref with 1-pair md rc=%d\n",rc); s=e=77; printf("  off0=%d s=%zu e=%zu\n",zuregex_capi_offsets(m0,0,&s,&e),s,e); zuregex_capi_match_data_free(m0); zuregex_capi_free(z); zuregex_capi_free(b);}
    // free pattern before match data, then use offsets + free md
    zr_pattern*t=C("(x)(y)",(size_t)-1,0,0,err,sizeof err); zr_match_data*mt=zuregex_capi_match_data_create(t); SHOW(zuregex_capi_match(t,"xy",2,0,0,mt)); zuregex_capi_free(t); s=e=77; SHOW(zuregex_capi_offsets(mt,2,&s,&e)); printf("s=%zu e=%zu\n",s,e); SHOW(zuregex_capi_match(p,"77",2,0,0,mt)); zuregex_capi_match_data_free(mt);
    zuregex_capi_free(g5); zuregex_capi_free(g5n); zuregex_capi_free(q); zuregex_capi_free(qj); zuregex_capi_match_data_free(md);}
  // bytes pattern on invalid utf, utf pattern
  { zr_pattern*b=C("\xff+",2,ZR_BYTES,0,err,sizeof err); zr_match_data*md=zuregex_capi_match_data_create(b); SHOW(zuregex_capi_match(b,"a\xff\xff",3,0,0,md)); size_t s,e; zuregex_capi_offsets(md,0,&s,&e); printf("s=%zu e=%zu\n",s,e); char out[16]; size_t n=16; int rc=SUB(b,"a\xff\xff",3,"\xfe",1,0,md,out,&n); printf("bytes sub rc=%d n=%zu\n",rc,n); zuregex_capi_match_data_free(md); zuregex_capi_free(b);}
  // NOTEMPTY
  { zr_pattern*b=C("a*",2,0,0,err,sizeof err); zr_match_data*md=zuregex_capi_match_data_create(b); SHOW(zuregex_capi_match(b,"baa",3,0,ZR_NOTEMPTY,md)); size_t s,e; zuregex_capi_offsets(md,0,&s,&e); printf("s=%zu e=%zu\n",s,e); SHOW(zuregex_capi_match(b,"b",1,0,ZR_NOTEMPTY,md)); SHOW(zuregex_capi_match(b,"baa",3,0,ZR_NOTEMPTY_ATSTART,md)); zuregex_capi_offsets(md,0,&s,&e); printf("s=%zu e=%zu\n",s,e); SHOW(zuregex_capi_match(b,"baa",3,0,ZR_NO_JIT_MATCH,md)); zuregex_capi_match_data_free(md); zuregex_capi_free(b);}
  zuregex_capi_free(p);
  return 0;}

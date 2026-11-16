// Probe 1: C API contracts
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "capi.h"
#define C zuregex_capi_compile
#define SHOW(x) printf("%-60s = %d\n", #x, (int)(x))
static void dump(const char *tag, const char *b, size_t n){printf("%s [",tag);for(size_t i=0;i<n;i++)printf(b[i]>=32&&b[i]<127?"%c":"\\x%02x",(unsigned char)b[i]);printf("]\n");}
int main(void){
  char err[256];
  // --- compile errbuf sizes
  for (size_t el=0; el<=3; el++){ char e[8]; memset(e,'#',8); zr_pattern*p=C("a(b",3,0,0,e,el); printf("errlen=%zu p=%p ",el,(void*)p); dump("errbuf",e,8);}
  { memset(err,'#',sizeof err); zr_pattern*p=C("a(b",3,0,0,err,sizeof err); printf("p=%p err='%s'\n",(void*)p,err);}
  { zr_pattern*p=C("a(b",3,0,0,NULL,10); printf("NULL errbuf p=%p\n",(void*)p);}
  // success: is errbuf touched?
  { memset(err,'#',sizeof err); err[10]=0; zr_pattern*p=C("ab",2,0,0,err,sizeof err); printf("ok p!=NULL %d err after success='%s'\n",p!=NULL,err); zuregex_capi_free(p);}
  // SIZE_MAX, NULL pattern
  { zr_pattern*p=C("abc",(size_t)-1,0,0,err,sizeof err); SHOW(p!=NULL); zuregex_capi_free(p);}
  { err[0]=0; zr_pattern*p=C(NULL,(size_t)-1,0,0,err,sizeof err); printf("NULL,SIZE_MAX p=%p err='%s'\n",(void*)p,err);}
  { err[0]=0; zr_pattern*p=C(NULL,0,0,0,err,sizeof err); printf("NULL,0 p=%p err='%s'\n",(void*)p,err); if(p){zr_match_data*md=zuregex_capi_match_data_create(p); SHOW(zuregex_capi_match(p,NULL,0,0,0,md)); SHOW(zuregex_capi_match(p,"abc",3,3,0,md)); size_t s=9,e=9; SHOW(zuregex_capi_offsets(md,0,&s,&e)); printf("s=%zu e=%zu\n",s,e); zuregex_capi_match_data_free(md);} zuregex_capi_free(p);}
  { err[0]=0; zr_pattern*p=C("abc",(size_t)-2,0,0,err,sizeof err); printf("SIZE_MAX-1 p=%p err='%s'\n",(void*)p,err);}
  // embedded NUL pattern
  { zr_pattern*p=C("a\0b",3,0,0,err,sizeof err); SHOW(p!=NULL); zr_match_data*md=zuregex_capi_match_data_create(p); SHOW(zuregex_capi_match(p,"xa\0b",4,0,0,md)); zuregex_capi_match_data_free(md); zuregex_capi_free(p);}
  // flags
  { err[0]=0; zr_pattern*p=C("a",1,0x8000,0,err,sizeof err); printf("flag 0x8000 p=%p err='%s'\n",(void*)p,err);}
  { err[0]=0; zr_pattern*p=C("a",1,0x80000,0,err,sizeof err); printf("flag 0x80000 p=%p err='%s'\n",(void*)p,err);}
  { err[0]=0; zr_pattern*p=C("a",1,0,2,err,sizeof err); printf("dialect 2 p=%p err='%s'\n",(void*)p,err);}
  { err[0]=0; zr_pattern*p=C("a",1,0,-1,err,sizeof err); printf("dialect -1 p=%p err='%s'\n",(void*)p,err);}
  // literal with other flags
  { err[0]=0; zr_pattern*p=C("a.b",3,ZR_LITERAL|ZR_MULTILINE,0,err,sizeof err); printf("literal|m p=%p err='%s'\n",(void*)p,err); zuregex_capi_free(p);}
  { err[0]=0; zr_pattern*p=C("a.b",3,ZR_LITERAL,ZR_DIALECT_JS,err,sizeof err); printf("literal js p=%p err='%s'\n",(void*)p,err); zuregex_capi_free(p);}
  { err[0]=0; zr_pattern*p=C("a.b",3,ZR_LITERAL|ZR_UCP,0,err,sizeof err); printf("literal|u p=%p err='%s'\n",(void*)p,err); zuregex_capi_free(p);}
  { err[0]=0; zr_pattern*p=C("a.b",3,ZR_EXTENDED|ZR_EXTENDED_MORE,0,err,sizeof err); printf("x|xx p=%p err='%s'\n",(void*)p,err); zuregex_capi_free(p);}
  { err[0]=0; zr_pattern*p=C("a\\Cb",4,0,0,err,sizeof err); printf("\\C utf p=%p err='%s'\n",(void*)p,err); zuregex_capi_free(p);}
  { err[0]=0; zr_pattern*p=C("(*UTF)a",7,ZR_BYTES,0,err,sizeof err); printf("(*UTF) bytes p=%p err='%s'\n",(void*)p,err); zuregex_capi_free(p);}
  { err[0]=0; zr_pattern*p=C("(*UCP)a",7,ZR_BYTES,0,err,sizeof err); printf("(*UCP) bytes p=%p err='%s'\n",(void*)p,err); zuregex_capi_free(p);}
  { err[0]=0; zr_pattern*p=C("\xff",1,0,0,err,sizeof err); printf("invalid utf pattern p=%p err='%s'\n",(void*)p,err); zuregex_capi_free(p);}
  { err[0]=0; zr_pattern*p=C("\xc3\xa9\xc3\xa9(",5,0,0,err,sizeof err); printf("utf err offset p=%p err='%s'\n",(void*)p,err); zuregex_capi_free(p);}
  // NULL handles
  SHOW(zuregex_capi_group_count(NULL)); SHOW(zuregex_capi_group_number(NULL,"a")); SHOW(zuregex_capi_group_name(NULL,1)==NULL); SHOW(zuregex_capi_jit(NULL));
  SHOW(zuregex_capi_match_data_create(NULL)==NULL); zuregex_capi_match_data_free(NULL); zuregex_capi_free(NULL);
  SHOW(zuregex_capi_set_limits(NULL,1,1,1));
  // groups
  { zr_pattern*p=C("(?<a>x)(y)(?<bb>z)",(size_t)-1,0,0,err,sizeof err);
    SHOW(zuregex_capi_group_count(p)); SHOW(zuregex_capi_group_number(p,"a")); SHOW(zuregex_capi_group_number(p,"bb")); SHOW(zuregex_capi_group_number(p,"b")); SHOW(zuregex_capi_group_number(p,"")); SHOW(zuregex_capi_group_number(p,"zz"));
    SHOW(zuregex_capi_group_number(p,NULL));
    for(int g=-1;g<=4;g++){const char*n=zuregex_capi_group_name(p,g); printf("group_name(%d)=%s\n",g,n?n:"(null)");}
    printf("group_name(INT_MAX)=%p (65536+1)=%p\n",(void*)zuregex_capi_group_name(p,2147483647),(void*)zuregex_capi_group_name(p,65537));
    zr_match_data*md=zuregex_capi_match_data_create(p); size_t s=77,e=77;
    // offsets before any match
    for(int g=-1;g<=4;g++){s=e=77; int rc=zuregex_capi_offsets(md,g,&s,&e); printf("before match: offsets(%d)=%d s=%zu e=%zu\n",g,rc,s,e);}
    SHOW(zuregex_capi_match(p,"..xyz",5,0,0,md));
    for(int g=-1;g<=4;g++){s=e=77; int rc=zuregex_capi_offsets(md,g,&s,&e); printf("offsets(%d)=%d s=%zu e=%zu\n",g,rc,s,e);}
    SHOW(zuregex_capi_offsets(md,0,NULL,&e)); SHOW(zuregex_capi_offsets(NULL,0,&s,&e));
    // start straddle
    SHOW(zuregex_capi_match(p,"..xyz",5,2,0,md)); SHOW(zuregex_capi_match(p,"..xyz",5,3,0,md)); SHOW(zuregex_capi_match(p,"..xyz",5,5,0,md)); SHOW(zuregex_capi_match(p,"..xyz",5,6,0,md)); SHOW(zuregex_capi_match(p,"..xyz",5,(size_t)-1,0,md));
    // after failed match offsets
    s=e=77; SHOW(zuregex_capi_offsets(md,0,&s,&e)); printf("s=%zu e=%zu\n",s,e);
    // options
    SHOW(zuregex_capi_match(p,"..xyz",5,0,ZR_ANCHORED,md)); SHOW(zuregex_capi_match(p,"..xyz",5,2,ZR_ANCHORED,md)); SHOW(zuregex_capi_match(p,"..xyz.",6,0,ZR_ENDANCHORED,md)); SHOW(zuregex_capi_match(p,"..xyz",5,0,0x20,md)); SHOW(zuregex_capi_match(p,"..xyz",5,0,0x80000000u,md));
    SHOW(zuregex_capi_match(p,NULL,1,0,0,md)); SHOW(zuregex_capi_match(NULL,"a",1,0,0,md)); SHOW(zuregex_capi_match(p,"a",1,0,0,NULL));
    // match after arg error: offsets?
    SHOW(zuregex_capi_match(p,"..xyz",5,0,0,md)); SHOW(zuregex_capi_match(p,"..xyz",5,9,0,md)); s=e=77; SHOW(zuregex_capi_offsets(md,0,&s,&e)); printf("after ARG error: s=%zu e=%zu (stale?)\n",s,e);
    // SIZE_MAX subject len
    SHOW(zuregex_capi_match(p,"..xyz",(size_t)-1,0,0,md)); s=e=77; SHOW(zuregex_capi_offsets(md,0,&s,&e)); printf("s=%zu e=%zu\n",s,e);
    // utf
    SHOW(zuregex_capi_match(p,"\xff xyz",5,0,0,md)); SHOW(zuregex_capi_match(p,"\xc3\xa9xyz",5,1,0,md));
    zuregex_capi_match_data_free(md); zuregex_capi_free(p);}
  // optional group not participating, trailing
  { zr_pattern*p=C("(a)|(b)(c)?",(size_t)-1,0,0,err,sizeof err); zr_match_data*md=zuregex_capi_match_data_create(p); size_t s,e;
    SHOW(zuregex_capi_match(p,"b",1,0,0,md)); for(int g=0;g<=4;g++){s=e=77; int rc=zuregex_capi_offsets(md,g,&s,&e); printf("offsets(%d)=%d s=%zu e=%zu\n",g,rc,s,e);}
    SHOW(zuregex_capi_match(p,"a",1,0,0,md)); for(int g=0;g<=4;g++){s=e=77; int rc=zuregex_capi_offsets(md,g,&s,&e); printf("offsets(%d)=%d s=%zu e=%zu\n",g,rc,s,e);}
    zuregex_capi_match_data_free(md); zuregex_capi_free(p);}
  // dupnames
  { zr_pattern*p=C("(?<n>a)|(?<n>b)",(size_t)-1,ZR_DUPNAMES,0,err,sizeof err); SHOW(p!=NULL); SHOW(zuregex_capi_group_number(p,"n")); printf("name1=%s name2=%s\n",zuregex_capi_group_name(p,1),zuregex_capi_group_name(p,2)); zuregex_capi_free(p);}
  { zr_pattern*p=C("(?|(?<n>a)|(?<n>b))",(size_t)-1,0,0,err,sizeof err); SHOW(p!=NULL); if(p){SHOW(zuregex_capi_group_count(p));SHOW(zuregex_capi_group_number(p,"n"));} zuregex_capi_free(p);}
  // \K with lookbehind: start > end
  { zr_pattern*p=C("(?=ab\\K)",(size_t)-1,0,0,err,sizeof err); printf("K in lookahead p=%p err=%s\n",(void*)p,p?"":err); if(p){zr_match_data*md=zuregex_capi_match_data_create(p); size_t s,e; SHOW(zuregex_capi_match(p,"ab",2,0,0,md)); zuregex_capi_offsets(md,0,&s,&e); printf("s=%zu e=%zu\n",s,e); zuregex_capi_match_data_free(md);} zuregex_capi_free(p);}
  // version/strerror
  printf("%s\n",zuregex_capi_version()); for(int c=1;c>=-13;c--)printf("%d:%s\n",c,zuregex_capi_strerror(c));
  return 0;}

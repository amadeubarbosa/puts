#
# source this file (source /usr/local/mico/mico.csh) in csh,tcsh to set
# up paths for MICO.
#

set    prefix="${OPENBUS_HOME}"
set    exec_prefix="${prefix}"
setenv MICODIR "$exec_prefix"
setenv MICOSHAREDDIR "$prefix"
setenv MICOVERSION ` sed -n '/MICO_VERSION/ { y/b/./; s#^[^"]*"\([^"]*\)".*$#\1#p; }' "$MICODIR/include/mico-2.3.13-singlethread/mico/version.h" `
setenv MICOBIN "$MICODIR/bin/mico-${MICOVERSION}-singlethread"
setenv PATH "$MICODIR/bin:$PATH"

if ( ! $?LD_LIBRARY_PATH )	setenv LD_LIBRARY_PATH ""
if ( ! $?SHLIB_PATH )		setenv SHLIB_PATH ""
if ( ! $?LIBPATH )		setenv LIBPATH ""
if ( ! $?MANPATH )		setenv MANPATH ""
if ( ! $?LIBRARY_PATH )		setenv LIBRARY_PATH ""
if ( ! $?CPLUS_INCLUDE_PATH )	setenv CPLUS_INCLUDE_PATH ""

setenv LD_LIBRARY_PATH "$MICODIR/lib/mico-${MICOVERSION}-singlethread:$LD_LIBRARY_PATH"
setenv DYLD_LIBRARY_PATH "$MICODIR/lib/mico-${MICOVERSION}-singlethread:$DYLD_LIBRARY_PATH"
setenv SHLIB_PATH "$MICODIR/lib/mico-${MICOVERSION}-singlethread:$SHLIB_PATH"
setenv LIBPATH "$MICODIR/lib/mico-${MICOVERSION}-singlethread:$LIBPATH"
setenv MANPATH "$MICOSHAREDDIR/man:$MANPATH"
setenv LIBRARY_PATH "$MICODIR/lib/mico-${MICOVERSION}-singlethread:$LIBRARY_PATH"
setenv CPLUS_INCLUDE_PATH "$MICODIR/include/mico-${MICOVERSION}-singlethread:$CPLUS_INCLUDE_PATH"

unset prefix
unset exec_prefix

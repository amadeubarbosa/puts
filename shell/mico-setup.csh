#
# source this file (source /usr/local/mico/mico.csh) in csh,tcsh to set
# up paths for MICO.
#

set    prefix="${OPENBUS_HOME}"
set    exec_prefix="${prefix}"
setenv MICODIR "$exec_prefix"
setenv MICOSHAREDDIR "$prefix"
setenv MICOVERSION ` sed -n '/MICO_VERSION/ { y/b/./; s#^[^"]*"\([^"]*\)".*$#\1#p; }' "$MICODIR/incpath/mico-2.3.13/mico/version.h" `
setenv PATH "$MICODIR/bin/${TEC_UNAME}:$PATH"

if ( ! $?LD_LIBRARY_PATH )	setenv LD_LIBRARY_PATH ""
if ( ! $?SHLIB_PATH )		setenv SHLIB_PATH ""
if ( ! $?LIBPATH )		setenv LIBPATH ""
if ( ! $?MANPATH )		setenv MANPATH ""
if ( ! $?LIBRARY_PATH )		setenv LIBRARY_PATH ""
if ( ! $?CPLUS_INCLUDE_PATH )	setenv CPLUS_INCLUDE_PATH ""

setenv LD_LIBRARY_PATH "$MICODIR/libpath/${TEC_UNAME}:$LD_LIBRARY_PATH"
setenv SHLIB_PATH "$MICODIR/libpath/${TEC_UNAME}:$SHLIB_PATH"
setenv LIBPATH "$MICODIR/libpath/${TEC_UNAME}:$LIBPATH"
setenv MANPATH "$MICOSHAREDDIR/man:$MANPATH"
setenv LIBRARY_PATH "$MICODIR/libpath/${TEC_UNAME}:$LIBRARY_PATH"
setenv CPLUS_INCLUDE_PATH "$MICODIR/incpath/mico-2.3.13/mico:$CPLUS_INCLUDE_PATH"

unset prefix
unset exec_prefix

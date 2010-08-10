#
# source this file (. /usr/local/mico/mico.sh) in sh,ksh,zsh,bash to set
# up paths for MICO.
#

prefix="${OPENBUS_HOME}"
exec_prefix="${prefix}"
MICODIR="$exec_prefix"
MICOSHAREDDIR="$prefix"
MICOVERSION=` sed -n '/MICO_VERSION/ { y/b/./; s#^[^"]*"\([^"]*\)".*$#\1#p; }' \
  "$MICODIR/incpath/mico-2.3.13/mico/version.h" `
PATH="$MICODIR/bin/${TEC_UNAME}:$PATH"
LD_LIBRARY_PATH="$MICODIR/libpath/${TEC_UNAME}:${LD_LIBRARY_PATH:-}"
SHLIB_PATH="$MICODIR/libpath/${TEC_UNAME}:${SHLIB_PATH:-}"
LIBPATH="$MICODIR/libpath/${TEC_UNAME}:${LIBPATH:-}"
MANPATH="$MICOSHAREDDIR/man:${MANPATH:-}"
CPLUS_INCLUDE_PATH="$MICODIR/incpath/mico-2.3.13/mico"
LIBRARY_PATH="$MICODIR/libpath/${TEC_UNAME}"

export MICOVERSION PATH LD_LIBRARY_PATH MANPATH CPLUS_INCLUDE_PATH LIBRARY_PATH
export SHLIB_PATH LIBPATH MICODIR

unset prefix
unset exec_prefix

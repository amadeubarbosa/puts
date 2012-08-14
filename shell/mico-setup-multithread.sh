#
# source this file (. /usr/local/mico/mico.sh) in sh,ksh,zsh,bash to set
# up paths for MICO.
#

prefix="${OPENBUS_HOME}"
exec_prefix="${prefix}"
MICODIR="$exec_prefix"
MICOSHAREDDIR="$prefix"
MICOVERSION=` sed -n '/MICO_VERSION/ { y/b/./; s#^[^"]*"\([^"]*\)".*$#\1#p; }' \
  "$MICODIR/include/mico-2.3.13-multithread/mico/version.h" `
MICOBIN="$MICODIR/bin/mico-${MICOVERSION}-multithread"
PATH="$MICODIR/bin/mico-${MICOVERSION}-multithread:$PATH"
LD_LIBRARY_PATH="$MICODIR/lib/mico-${MICOVERSION}-multithread:${LD_LIBRARY_PATH:-}"
DYLD_LIBRARY_PATH="$MICODIR/lib/mico-${MICOVERSION}-multithread:${DYLD_LIBRARY_PATH:-}"
SHLIB_PATH="$MICODIR/lib/mico-${MICOVERSION}-multithread:${SHLIB_PATH:-}"
LIBPATH="$MICODIR/lib/mico-${MICOVERSION}-multithread:${LIBPATH:-}"
MANPATH="$MICOSHAREDDIR/man:${MANPATH:-}"
CPLUS_INCLUDE_PATH="$MICODIR/include/mico-${MICOVERSION}-multithread"
LIBRARY_PATH="${LIBRARY_PATH}:$MICODIR/lib/mico-${MICOVERSION}-multithread"

export MICOVERSION PATH LD_LIBRARY_PATH DYLD_LIBRARY_PATH MANPATH CPLUS_INCLUDE_PATH LIBRARY_PATH
export SHLIB_PATH LIBPATH MICODIR MICOBIN

unset prefix
unset exec_prefix

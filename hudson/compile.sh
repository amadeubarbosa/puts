#!/bin/ksh

# Para teste sem o hudson
# Configuração para máquina ferradura
#export WORKSPACE=/local/openbus/hudson/jobs/OpenBus/workspace
# Configuração para máquina delaunay
#export WORKSPACE=/local/openbus/hudson/workspace/SPARC

[ -n "$(which lua5.1 2>/dev/null)" ] || \
  (echo "ERRO: Não encontrei o binário do lua5.1!" && exit 1)

. ${WORKSPACE}/hudson/openbus.sh

cd ${WORKSPACE}/puts/lua/tools
cp ${WORKSPACE}/hudson/toolsconf.lua .

lua5.1 console.lua --config=toolsconf.lua --compile -verbose --update --force  "$@"

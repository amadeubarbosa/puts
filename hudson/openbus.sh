#!/bin/ksh
###############################################################################
# Compatibilidade: poder rodar sem o Hudson

if [ -z "${BUILD_NUMBER}" ] ;then
  export BUILD_NUMBER=1
  echo "[WARN] Variável de ambiente BUILD_NUMBER não definida: usando '${BUILD_NUMBER}'"
fi 
if [ -z "${BUILD_ID}" ] ;then
  export BUILD_ID=OpenBus
  echo "[WARN] Variável de ambiente BUILD_ID não definida: usando '${BUILD_ID}'"
fi 

###############################################################################
# Limpeza de ambiente
export OPENSSL_HOME=""
export LD_LIBRARY_PATH=""
export LIBRARY_PATH=""
export CPATH=""
export LUA_PATH=""
export LUA_CPATH=""

# Localização do MAVEN
export M2_HOME="/home/msv/openbus/programas/maven/current"
export DAEMONIZE_HOME="/home/msv/openbus/programas/daemonize"
export M2="${M2_HOME}/bin"
export PATH="${M2}:${HUDSON_HOME}/sbin:${DAEMONIZE_HOME}/sbin/${TEC_UNAME}:${PATH}"

if [ "${TEC_SYSNAME}" == "Linux" ] ;then
  # Disparar o 'uuidd' para evitar prender a porta no ACS
  [ -n "$(which uuidd 2>/dev/null)"] && uuidd -q
  # Localização do ANT
  export ANT_HOME="/home/msv/openbus/programas/ant-1.7.1"
  export PATH="${ANT_HOME}/bin:${PATH}"
fi

if [ "${TEC_SYSNAME}" == "SunOS" ] ;then
  # Mudança para encontrar o binário do Lua5.1. 
  # Caso use-se o binário do puts pode comentar essas linhas abaixo
  export TECTOOLS_HOME="/home/t/tecgraf/lib"
  export PATH="${TECTOOLS_HOME}/lua5.1/bin/${TEC_UNAME}:${PATH}"
  export JAVA_HOME="/"
fi

###############################################################################
# Variáveis de ambiente do OpenBus

export OPENBUS_HOME="${OPENBUS_HOME:-${WORKSPACE}/install}"
###############################################################################

#!/bin/ksh

showLog()
{
  echo "================================ $1 Output Log ==============================="
  cat $2
  echo
  echo "================================ $1 Error Log ================================"
  cat $3
  echo
  echo "=============================================================================="
}

LOGIN=$1
OPENBUS_PATH=$2

if [ -z "${LOGIN}" ]; then
  echo "[ERRO] Login do administrador não foi definido"
  exit 1
fi

if [ -n "${OPENBUS_PATH}" ]; then
  OPENBUS_HOME=${OPENBUS_PATH}
fi

if [ -z "$OPENBUS_HOME" ]; then
  echo "[ERRO] Variavel OPENBUS_HOME não foi definida"
  exit 1
fi  

echo "Iniciando Serviço de Acesso"
ACSOUTFILE=acs.out
ACSERRFILE=acs.err
${OPENBUS_HOME}/core/bin/run_access_control_server.sh >>${ACSOUTFILE} 2>${ACSERRFILE} &
ACSPID=$!
sleep 5

# Verifica se o serviço está no ar.
if ! ( kill -0 ${ACSPID} 2>/dev/null 2>&1 ) ;then
  showLog "ACS" ${ACSOUTFILE} ${ACSERRFILE}
  rm -f ${ACSOUTFILE} ${ACSERRFILE}
  exit 1
fi

# Cadastra o ACS e o RS
cd ${OPENBUS_HOME}/tools/management
${OPENBUS_HOME}/core/bin/run_management.sh --login=${LOGIN} --script=access_control_service.mgt
${OPENBUS_HOME}/core/bin/run_management.sh --login=${LOGIN} --script=registry_service.mgt



echo "Iniciando Serviço de Registro"
RGSOUTFILE=rgs.out
RGSERRFILE=rgs.err
${OPENBUS_HOME}/core/bin/run_registry_server.sh >>${RGSOUTFILE} 2>${RGSERRFILE} &
RGSPID=$!
sleep 5

# Verifica se o serviço está no ar.
if ! ( kill -0 ${RGSPID} 2>/dev/null 2>&1 ) ;then
  showLog "RGS" ${RGSOUTFILE} ${RGSERRFILE}
  rm -f ${RGSOUTFILE} ${RGSERRFILE}
  rm -f ${ACSOUTFILE} ${ACSERRFILE}
  kill -9 ${ACSPID}
  exit 1
fi

#Cadastra o SS
cd ${OPENBUS_HOME}/tools/management
${OPENBUS_HOME}/core/bin/run_management.sh --login=${LOGIN} --script=session_service.mgt


#Finaliza os serviços
kill -9 ${RGSPID}
kill -9 ${ACSPID}

rm -f ${ACSOUTFILE} ${ACSERRFILE}
rm -f ${RGSOUTFILE} ${RGSERRFILE}


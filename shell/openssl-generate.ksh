#!/bin/ksh

# Script para gera��o da chave privada e do certificado digital para
# conex�o com o OpenBus.
# 
# $Id$

# Padr�o � usar do host
OPENSSL_CMD=openssl
sslConfig=

scriptName=$(basename $0)

function usage {
    cat << EOF

Uso: $scriptName [opcoes]

  onde [opcoes] sao:

  -h      : ajuda
  -c arq  : arquivo de configuracao do OpenSSL
  -n nome : nome da entidade para a qual a chave privada e o certificado ser�o gerados

OBS.: se o nome nao for fornecido via '-n' sera obtido interativamente
EOF
}

function checkOpenSSL {
  which openssl > /dev/null 2>&1
  if [ $? == "1" ]; then
    echo "============================================================="
    echo "[ERRO] O aplicativo 'openssl' n�o foi encontrado."
    echo "============================================================="
    return 1
  fi
}

while getopts "hc:n:" params; do
     case $params in
        h)
            usage
            exit 0
        ;;
        c)
            sslConfig="-config $OPTARG"
        ;;
        n)
            entityName="$OPTARG"
        ;;
        *)
            usage
            exit 1
        ;;
     esac
done

# descartamos os parametros processados
shift $((OPTIND - 1))

if [ -z "$entityName" ]; then
  echo -n "Digite o nome da chave: "
  read entityName
fi

# OpenBus configurado, usar nossa instala��o. Sen�o, usar do host.
if [ -n "${OPENBUS_HOME}" ]; then
  OPENSSL_CMD="${OPENBUS_HOME}/bin/${TEC_UNAME}/openssl"
  # Verifica se o OpenBus instalou o OpenSSL, caso contr�rio, mant�m o padr�o.
  if [ -x "${OPENSSL_CMD}" ]; then
    export OPENSSL_HOME="${OPENBUS_HOME}/openssl"
  else
    checkOpenSSL
    OPENSSL_CMD=openssl
  fi
  # Se usu�rio n�o informar arquivo de configura��o usaremos aquele distribu�do no OpenBus.
  if [ -z "$sslConfig" ]; then
    sslConfig="-config ${OPENBUS_HOME}/openssl/openssl.cnf"
  fi
else
  checkOpenSSL
fi

echo "============================================================="
echo "Criando certificados para o Openbus ..."
echo "Comando 'openssl' utilizado : ${OPENSSL_CMD}"
echo "============================================================="

${OPENSSL_CMD} genrsa -out ${entityName}_openssl.key 2048
${OPENSSL_CMD} pkcs8 -topk8 -in ${entityName}_openssl.key \
    -nocrypt > ${entityName}.key

${OPENSSL_CMD} req ${sslConfig} -new -x509 -key ${entityName}.key \
    -out ${entityName}.crt -outform DER

rm -f ${entityName}_openssl.key

echo "============================================================="
echo "Chave privada : ${entityName}.key"
echo "Certificado   : ${entityName}.crt"
echo "============================================================="

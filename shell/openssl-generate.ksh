#!/bin/ksh


echo --- Criando certificados para o Openubs ---
echo 

which openssl 2> /dev/null 1> /dev/null
if [ $? == "1" ]; then
  echo Não foi encontrado o openssl
  return 1
fi

if [ -n "$1" ]; then
  NAME=$1
else
  echo -n "digite o nome da chave:"
  read NAME
fi

openssl genrsa -out ${NAME}_openssl.key 2048
openssl pkcs8 -topk8 -in ${NAME}_openssl.key -nocrypt > ${NAME}.key
openssl req -new -x509 -key ${NAME}.key -out ${NAME}.crt -outform DER

rm -f ${NAME}_openssl.key

#!/bin/csh
#  This script sets environment variables for domain sample-domain

# example in solaris
#setenv ORBIX_HOME /home/msv/openbus/third-party/orbix63sun510sparc/asp/6.3

if ( ! $?ORBIX_HOME ) then
  echo "Missing ORBIX_HOME system variable."
else
  echo Setting ORBIX environment for domain sample-domain

  setenv PATH "${ORBIX_HOME}/bin:${ORBIX_HOME}/../../etc/bin:${PATH}"
  setenv IT_PRODUCT_DIR "${ORBIX_HOME}/../../"
  setenv IT_DOMAIN_NAME "sample-domain"
  setenv IT_CONFIG_DOMAINS_DIR "${ORBIX_HOME}/../../etc/domains"
  setenv IT_LICENSE_FILE "${ORBIX_HOME}/../../etc/licenses.txt"

  #: ${CLASSPATH:=""}
  #setenv CLASSPATH "${ORBIX_HOME}/lib/asp-corba.jar:${ORBIX_HOME}/../../etc/domains/sample-domain:$CLASSPATH"

  #: ${LD_LIBRARY_PATH:=""}
  setenv LD_LIBRARY_PATH "${ORBIX_HOME}/../../shlib:${ORBIX_HOME}/../../shlib/default:$LD_LIBRARY_PATH"

  #: ${LD_LIBRARY_PATH_64:=""}
  setenv LD_LIBRARY_PATH_64 "${ORBIX_HOME}/../../shlib:${ORBIX_HOME}/../../shlib/default:$LD_LIBRARY_PATH_64"

  if (`uname -s` == "SunOS") then
    setenv LD_LIBRARY_PATH "$LD_LIBRARY_PATH:${ORBIX_HOME}/../../shlib/sparcv9:${ORBIX_HOME}/../../shlib/default/sparcv9"
    setenv LD_LIBRARY_PATH_64 "${ORBIX_HOME}/../../shlib/sparcv9:${ORBIX_HOME}/../../shlib/default/sparcv9:$LD_LIBRARY_PATH_64"
  else
    setenv LD_LIBRARY_PATH "$LD_LIBRARY_PATH:${ORBIX_HOME}/../../shlib/lib64:${ORBIX_HOME}/../../shlib/default/lib64"
    setenv LD_LIBRARY_PATH_64 "${ORBIX_HOME}/../../shlib/lib64:${ORBIX_HOME}/../../shlib/default/lib64:$LD_LIBRARY_PATH_64"
  endif
endif
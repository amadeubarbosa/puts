#!/bin/csh
#  This script sets environment variables for domain sample-domain

# linux
setenv ORBIX_PATH /home/msv/rcosme/tools/orbix63
# solaris
#setenv ORBIX_PATH /home/msv/rcosme/tools/orbixSunOS510

echo Setting environment for domain sample-domain

setenv PATH "${ORBIX_PATH}/asp/6.3/bin:${ORBIX_PATH}/etc/bin:${PATH}"

setenv IT_PRODUCT_DIR "${ORBIX_PATH}"

setenv IT_DOMAIN_NAME "sample-domain"

setenv IT_CONFIG_DOMAINS_DIR "${ORBIX_PATH}/etc/domains"

setenv IT_LICENSE_FILE "${ORBIX_PATH}/etc/licenses.txt"

#: ${CLASSPATH:=""}

#setenv CLASSPATH "${ORBIX_PATH}/asp/6.3/lib/asp-corba.jar:${ORBIX_PATH}/etc/domains/sample-domain:$CLASSPATH"

#: ${LD_LIBRARY_PATH:=""}

setenv LD_LIBRARY_PATH "${ORBIX_PATH}/shlib:${ORBIX_PATH}/shlib/default:${ORBIX_PATH}/shlib/lib64:${ORBIX_PATH}/shlib/default/lib64:/usr/java/jre/lib/sparc:/usr/java/jre/lib/sparc/server:$LD_LIBRARY_PATH"

#: ${LD_LIBRARY_PATH_64:=""}

#setenv LD_LIBRARY_PATH_64 "${ORBIX_PATH}/shlib/lib64:${ORBIX_PATH}/shlib/default/lib64:${ORBIX_PATH}/shlib:${ORBIX_PATH}/shlib/default:$LD_LIBRARY_PATH_64"


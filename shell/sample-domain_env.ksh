#!/bin/ksh
#  This script sets environment variables for domain sample-domain

# example in solaris
#export ORBIX_HOME=/home/msv/openbus/third-party/orbix63sun510sparc/asp/6.3

if [ -z "${ORBIX_HOME}" ]; then
  echo "Missing ORBIX_HOME system variable."
else
  echo Setting ORBIX environment for domain sample-domain

  PATH=$ORBIX_HOME/bin:$ORBIX_HOME/../../etc/bin:$PATH
  export PATH

  export IT_PRODUCT_DIR="$ORBIX_HOME/../../"
  export IT_DOMAIN_NAME="sample-domain"
  export IT_CONFIG_DOMAINS_DIR="$ORBIX_HOME/../../etc/domains"
  export IT_LICENSE_FILE="$ORBIX_HOME/../../etc/licenses.txt"

  #: ${CLASSPATH:=""}
  #CLASSPATH=$ORBIX_HOME/lib/asp-corba.jar:$ORBIX_HOME/../../etc/domains/sample-domain:$CLASSPATH:; export CLASSPATH

  #: ${LD_LIBRARY_PATH:=""}
  LD_LIBRARY_PATH="$ORBIX_HOME/../../shlib:$ORBIX_HOME/../../shlib/default:$LD_LIBRARY_PATH"

  #: ${LD_LIBRARY_PATH_64:=""}
  LD_LIBRARY_PATH_64="$ORBIX_HOME/../../shlib:$ORBIX_HOME/shlib/default:$LD_LIBRARY_PATH_64"

  if [ "`uname -s`" == "SunOS" ]
  then
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$ORBIX_HOME/../../shlib/sparcv9:$ORBIX_HOME/../../shlib/default/sparcv9"
    LD_LIBRARY_PATH_64="$ORBIX_HOME/../../shlib/sparcv9:$ORBIX_HOME/../../shlib/default/sparcv9:$LD_LIBRARY_PATH_64"
  else
    LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$ORBIX_HOME/../../shlib/lib64:$ORBIX_HOME/../../shlib/default/lib64"
    LD_LIBRARY_PATH_64="$ORBIX_HOME/../../shlib/lib64:$ORBIX_HOME/../../shlib/default/lib64:$LD_LIBRARY_PATH_64"
  fi

  export LD_LIBRARY_PATH
  export LD_LIBRARY_PATH_64
fi
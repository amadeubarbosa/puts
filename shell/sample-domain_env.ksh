#!/bin/ksh
#  This script sets environment variables for domain sample-domain

# linux
export ORBIX_HOME=/home/msv/rcosme/tools/orbix63/asp/6.3
# solaris
#export ORBIX_HOME=/home/msv/rcosme/tools/orbixSunOS510/asp/6.3

echo Setting environment for domain sample-domain

PATH=$ORBIX_HOME/bin:$ORBIX_HOME/../../etc/bin:$PATH; export PATH

export IT_PRODUCT_DIR="$ORBIX_HOME/../../"

export IT_DOMAIN_NAME="sample-domain"

export IT_CONFIG_DOMAINS_DIR="$ORBIX_HOME/../../etc/domains"

export IT_LICENSE_FILE="$ORBIX_HOME/../../etc/licenses.txt"

#: ${CLASSPATH:=""}

#CLASSPATH=$ORBIX_HOME/lib/asp-corba.jar:$ORBIX_HOME/../../etc/domains/sample-domain:$CLASSPATH:; export CLASSPATH

#: ${LD_LIBRARY_PATH:=""}

export LD_LIBRARY_PATH="$ORBIX_HOME/../../shlib:$ORBIX_HOME/../../shlib/default:$ORBIX_HOME/../../shlib/lib64:$ORBIX_HOME/../../shlib/default/lib64:/usr/java/jdk1.6.0_07/jre/lib/sparc:/usr/java/jdk1.6.0_07/jre/lib/sparc/server:$LD_LIBRARY_PATH"

#: ${LD_LIBRARY_PATH_64:=""}

#LD_LIBRARY_PATH_64=$ORBIX_HOME/../../shlib/lib64:$ORBIX_HOME/../../shlib/default/lib64:$ORBIX_HOME/../../shlib:$ORBIX_HOME/shlib/default:$LD_LIBRARY_PATH_64; export LD_LIBRARY_PATH_64


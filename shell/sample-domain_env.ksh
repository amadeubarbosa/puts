#!/bin/ksh
#  This script sets environment variables for domain sample-domain

# linux
ORBIX_PATH=/home/msv/rcosme/tools/orbix63
# solaris
#ORBIX_PATH=/home/msv/rcosme/tools/orbixSunOS510

echo Setting environment for domain sample-domain

PATH=$ORBIX_PATH/asp/6.3/bin:$ORBIX_PATH/etc/bin:$PATH; export PATH

export IT_PRODUCT_DIR="$ORBIX_PATH"

export IT_DOMAIN_NAME="sample-domain"

export IT_CONFIG_DOMAINS_DIR="$ORBIX_PATH/etc/domains"

export IT_LICENSE_FILE="$ORBIX_PATH/etc/licenses.txt"

#: ${CLASSPATH:=""}

#CLASSPATH=$ORBIX_PATH/asp/6.3/lib/asp-corba.jar:$ORBIX_PATH/etc/domains/sample-domain:$CLASSPATH:; export CLASSPATH

#: ${LD_LIBRARY_PATH:=""}

export LD_LIBRARY_PATH="$ORBIX_PATH/shlib:$ORBIX_PATH/shlib/default:$ORBIX_PATH/shlib/lib64:$ORBIX_PATH/shlib/default/lib64:/usr/java/jdk1.6.0_07/jre/lib/sparc:/usr/java/jdk1.6.0_07/jre/lib/sparc/server:$LD_LIBRARY_PATH"

#: ${LD_LIBRARY_PATH_64:=""}

#LD_LIBRARY_PATH_64=$ORBIX_PATH/shlib/lib64:$ORBIX_PATH/shlib/default/lib64:$ORBIX_PATH/shlib:$ORBIX_PATH/shlib/default:$LD_LIBRARY_PATH_64; export LD_LIBRARY_PATH_64


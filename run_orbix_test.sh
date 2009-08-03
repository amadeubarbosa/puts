#!/bin/ksh

# helpers
function is_dir {
	dir=$1
	if [ ! -d "$dir" ]; then
		echo "ERROR: Missing directory $dir"
		return 1
	fi
	return 0
}
function die {
	echo -e $@
	exit 1
}

# all checks before execute
[ "$TEC_UNAME" == "" ] && die "ERROR: Missing TEC_UNAME system variable, aborting."

if [ "$1" != "" ] && [ "$2" != "" ]
then
	export OPENBUS_HOME=$1
	## it'll be used just on launching of unit tests
	export OPENBUS_HOME_DEVEL=$2
	echo -e "INFO: We will run basic services from $OPENBUS_HOME"
	echo -e "INFO: and the test suite will run from $OPENBUS_HOME_DEVEL \n"
else
	if [ "$OPENBUS_HOME" == "" ] || [ "$OPENBUS_HOME_DEVEL" == "" ]
	then
		die "ERROR: Missing arguments: you should provide OPENBUS_HOME and OPENBUS_HOME_DEVEL paths\n" \
		"Usage: `basename $0` <openbus_home> <openbus_path with test suites>\n" \
		"  You could define OPENBUS_HOME and OPENBUS_HOME_DEVEL as system variables also"
	fi
fi

is_dir "$OPENBUS_HOME/core/bin/$TEC_UNAME" || die "ERROR: $OPENBUS_HOME seems an invalid OPENBUS_HOME"
is_dir "$OPENBUS_HOME_DEVEL/core/test/orbix" && 
is_dir "${OPENBUS_HOME_DEVEL}/incpath/cxxtest" &&

## loading basic variable definitions
. $OPENBUS_HOME/data/conf/config

## first starting services
cd $OPENBUS_HOME/core/bin

LOG=/tmp/ACS_log
echo " >>>>>>>>>>>> Starting ACS (log: $LOG) <<<<<<<<<<<<<< "
./run_access_control_server.sh >$LOG&
ACS_PID=$!
sleep 20

LOG=/tmp/RGS_log
echo " >>>>>>>>>>>> Starting RGS (log: $LOG) <<<<<<<<<<<<<< "
./run_registry_server.sh >$LOG&
RS_PID=$!
sleep 10

LOG=/tmp/SES_log
echo " >>>>>>>>>>>> Starting SES (log: $LOG) <<<<<<<<<<<<<< "
./run_session_server.sh >$LOG&
SS_PID=$!
sleep 10

echo PIDS: $ACS_PID $RS_PID $SS_PID
cd -

## now starting the tests
cd $OPENBUS_HOME_DEVEL/core/test/orbix

TESTS_TORUN="
acs
rgs"
#ses
#das

## redefining OPENBUS_HOME to get right cxxtest, tolua5.1
## the present configuration on core/conf/config
export OPENBUS_HOME=${OPENBUS_HOME_DEVEL}

for test in $TESTS_TORUN;
do 
	echo " >>>>>>>>>>>> Running the test named $test <<<<<<<<<<<<<< "
	cd $test
	tecmake cxxtest
	tecmake rebuild
	cd ../
	./runtests $test
	sleep 2
done

echo " >>>>>>>>>>>> Waiting 10s for kill basic services... <<<<<<<<<<<<<< "
sleep 10
kill -9 $ACS_PID $RS_PID $SS_PID
pkill -9 servicelauncher

cd -


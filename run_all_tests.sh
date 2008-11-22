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
	echo $@
	exit 1
}

# all checks before execute
[ "$TEC_UNAME" == "" ] && die "ERROR: Missing TEC_UNAME system variable, aborting."

if [ "$1" != "" ] && [ "$2" != "" ]
then
	export OPENBUS_HOME=$1
	## it'll be used just on launching of unit tests
	export OPENBUS_HOME_DEVEL=$2
	echo "INFO: We will run basic services from $OPENBUS_HOME"
	echo "INFO: and the test suite will run from $OPENBUS_HOME_DEVEL \n"
else
	if [ "$OPENBUS_HOME" == "" ] || [ "$OPENBUS_HOME_DEVEL" == "" ]
	then
		die "ERROR: Missing arguments: you should provide OPENBUS_HOME and OPENBUS_HOME_DEVEL paths\n" \
		"Usage: `basename $0` <openbus_home> <openbus_path with test suites>\n" \
		"  You could define OPENBUS_HOME and OPENBUS_HOME_DEVEL as system variables also"
	fi
fi

is_dir "$OPENBUS_HOME/core/bin/$TEC_UNAME" || die "ERROR: $OPENBUS_HOME seems an invalid OPENBUS_HOME"
is_dir "$OPENBUS_HOME_DEVEL/core/test/lua" && 
is_dir "${OPENBUS_HOME_DEVEL}/libpath/lua/5.1/latt" || exit 1

## loading basic variable definitions
. $OPENBUS_HOME/core/conf/config

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
cd $OPENBUS_HOME_DEVEL/core/test/lua

TESTS_TORUN="
testAccessControlService.lua
testRegistryService.lua
testSessionService.lua
reinitRegistry.lua
reinitSession.lua"
#testCSBaseDataService.lua
#testCSBaseProjectService.lua
#testEvents.lua
#testLdapAuthentication.lua

## redefining OPENBUS_HOME to get right LUA_PATH with latt
## the present configuration on core/conf/config redefines
## whole LUA_PATH pointing to OPENBUS_HOME/libpath/lua/5.1
export OPENBUS_HOME=${OPENBUS_HOME_DEVEL}

for test in $TESTS_TORUN;
do 
	echo " >>>>>>>>>>>> Running the test named $test <<<<<<<<<<<<<< "
	./run_unit_test.sh $test
	sleep 2
done

echo " >>>>>>>>>>>> Waiting 10s for kill basic services... <<<<<<<<<<<<<< "
sleep 10
kill -9 $ACS_PID $RS_PID $SS_PID
killall -9 servicelauncher

cd -

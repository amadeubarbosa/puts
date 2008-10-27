#!/bin/ksh

## it'll be used just on launching of unit tests
export OPENBUS_HOME_WITH_LATT=$HOME/work/install

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
cd $HOME/work/trunk/core/test/cppoil

TESTS_TORUN="
acs
rgs
ses
das"

## redefining OPENBUS_HOME to get right LUA_PATH with latt
## the present configuration on core/conf/config redefines
## whole LUA_PATH pointing to OPENBUS_HOME/libpath/lua/5.1
export OPENBUS_HOME=${OPENBUS_HOME_WITH_LATT}

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
killall -9 servicelauncher

cd -


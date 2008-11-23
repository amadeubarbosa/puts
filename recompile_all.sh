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

TOOLSDIR=$OPENBUS_HOME/../trunk/tools
LOGDIR=$OPENBUS_HOME/../

# all checks before execute
if [ "$OPENBUS_HOME" == "" ]
then 
	die "ERROR: Missing OPENBUS_HOME system variable"
else
	echo "INFO: Using OPENBUS_HOME as $OPENBUS_HOME"
	# we don't test core/bin/$TEC_UNAME because this script could be run from any host
	is_dir "$OPENBUS_HOME/core/bin" || die "ERROR: $OPENBUS_HOME seems an invalid OPENBUS_HOME"
fi

if [ ! -f $TOOLSDIR/compile.lua ]
then
	echo "INFO: We assume by default compile.lua on: $TOOLSDIR/compile.lua"
	echo "INFO:                 and the log file on: $LOGDIR"
	echo "INFO: But the compile.lua was not found!"
	echo "INFO: Where is the compile.lua? Please inform us or CTRL+C to abort."
	read NEWDIR
	[  -f "$NEWDIR/compile.lua" ] || die "ERROR: Invalid directory $NEWDIR!"
	echo "INFO: Thanks! Proceeding..."
	TOOLSDIR=$NEWDIR
fi

timestamp=$(date +%Y%m%d)
logfile="$LOGDIR/arch-built.$timestamp"
compile_cmd="cd $TOOLSDIR; ./compile.lua $@"

rm -f $logfile
touch $logfile

# compiling for each platform
for host_build in Linux24g3 Linux24g3_64 Linux26 Linux26_64 Linux26g4 Linux26g4_64 Linux26_ia64 SunOS58 SunOS510x86 murubira
do
	# registering on work/arch-built.$timestamp the platforms that compiles fine
	ssh $host_build $compile_cmd && ssh $host_build 'echo ${TEC_UNAME}' >> $logfile
done

# creating the tarballs
for tec_uname in `cat $logfile`
do 
	ssh Linux26g4 "cd $TOOLSDIR; ./makepack.lua --profile=admin --arch=$tec_uname"
done

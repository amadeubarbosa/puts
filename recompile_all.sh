#!/bin/ksh

timestamp=$(date +%Y%m%d)
logfile="work/arch-built.$timestamp"
compile_cmd="lua5.1 tools/compile.lua $@"

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
	ssh Linux26g4 "lua5.1 tools/makepack.lua --profile=admin --arch=$tec_uname"
done

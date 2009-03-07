#!/bin/ksh

cd $HOME/prodapp/lib/
for each in `ls`
do 
	rm -rf $each/{bin,lib,obj}/${TEC_UNAME}
done

# apagando fontes gerados pelo precompiler.lua
rm -rf oil04/obj/*/${TEC_UNAME}

cd $HOME/work/trunk
rm -rf core/{bin,obj}/${TEC_UNAME}
rm -rf core/services/servicelauncher.dep
rm -rf core/utilities/cppoil/openbus.dep
rm -rf core/utilities/cppoil/lib/${TEC_UNAME}
rm -rf core/utilities/cppoil/obj/${TEC_UNAME}
rm -rf core/utilities/orbix/openbus.dep
rm -rf core/utilities/orbix/lib/${TEC_UNAME}
rm -rf core/utilities/orbix/obj/${TEC_UNAME}
rm -rf core/test/cppoil/acs/acs.dep
rm -rf core/test/cppoil/acs/runner.cpp
rm -rf core/test/cppoil/rgs/rgs.dep
rm -rf core/test/cppoil/rgs/runner.cpp
rm -rf core/test/cppoil/ses/ses.dep
rm -rf core/test/cppoil/ses/runner.cpp
rm -rf core/test/cppoil/bin/${TEC_UNAME}
rm -rf core/test/cppoil/lib/${TEC_UNAME}
rm -rf core/test/cppoil/obj/${TEC_UNAME}
rm -rf core/test/orbix/acs/acs.dep
rm -rf core/test/orbix/acs/runner.cpp
rm -rf core/test/orbix/rgs/rgs.dep
rm -rf core/test/orbix/rgs/runner.cpp
rm -rf core/test/orbix/ses/ses.dep
rm -rf core/test/orbix/ses/runner.cpp
rm -rf core/test/orbix/bin/${TEC_UNAME}
rm -rf core/test/orbix/lib/${TEC_UNAME}
rm -rf core/test/orbix/obj/${TEC_UNAME}
rm -rf lib/lce/lib/${TEC_UNAME}
rm -rf lib/lce/obj/${TEC_UNAME}
rm -rf lib/lce/src/lce.dep
rm -rf lib/scs/lib/${TEC_UNAME}
rm -rf lib/scs/obj/${TEC_UNAME}
rm -rf lib/scs/src/scsoil.dep
rm -rf lib/scs/src/scsall.dep
rm -rf lib/scs/src/scsmico.dep
rm -rf lib/scs/src/scsorbix.dep
rm -rf lib/ftc/lib/${TEC_UNAME}
rm -rf lib/ftc/obj/${TEC_UNAME}
rm -rf lib/ftc/src/ftc.dep
rm -rf lib/ftc/src/ftcwooil.dep


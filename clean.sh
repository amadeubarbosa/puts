#!/bin/ksh

cd $HOME/prodapp/lib/
for each in `ls`
do 
	rm -rf $each/{bin,lib,obj}/${TEC_UNAME}
done

cd $HOME/work/trunk
rm -rf core/{bin,obj}/${TEC_UNAME}
rm -rf core/services/servicelauncher.dep
rm -rf core/utilities/cppoil/openbus.dep
rm -rf core/utilities/cppoil/lib/${TEC_UNAME}
rm -rf core/utilities/cppoil/obj/${TEC_UNAME}
rm -rf lib/lce/lib/${TEC_UNAME}
rm -rf lib/lce/obj/${TEC_UNAME}
rm -rf lib/lce/src/lce.dep
rm -rf lib/scs/lib/${TEC_UNAME}
rm -rf lib/scs/obj/${TEC_UNAME}
rm -rf lib/scs/src/scsoil.dep
rm -rf lib/scs/src/scsall.dep
rm -rf lib/ftc/lib/${TEC_UNAME}
rm -rf lib/ftc/obj/${TEC_UNAME}
rm -rf lib/ftc/src/ftc.dep
rm -rf lib/ftc/src/ftcwooil.dep


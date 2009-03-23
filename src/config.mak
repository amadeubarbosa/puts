PROJNAME= tools
APPNAME= ${PROJNAME}

LUABIN= ${LUA51}/bin/${TEC_UNAME}/lua5.1
LUA_FLAGS += -e 'package.path="../lua/?.lua;"..package.path'

OPENBUSLIB= ${OPENBUS_HOME}/libpath/${TEC_UNAME}

PRECMP_DIR= ../obj/${TEC_UNAME}
PRECMP_LUA= ../lua/precompiler.lua
PRECMP_FLAGS= -p TOOLS_API -o tools -d ${PRECMP_DIR}

PRELOAD_LUA= ../lua/preloader.lua
PRELOAD_FLAGS= -p TOOLS_API -o toolsall -d ${PRECMP_DIR}

TOOLS_LUA= $(addprefix ../lua/,\
	tools/config.lua \
	tools/build/tecmake.lua \
	tools/build/copy.lua \
	tools/build/autotools.lua \
	tools/checklibdeps.lua \
	tools/platforms.lua \
	tools/split.lua \
	tools/util.lua \
	tools/compile.lua \
	tools/installer.lua \
	tools/makepack.lua \
        tools/console.lua )

${PRECMP_DIR}/tools.c: $(TOOLS_LUA)
	$(LUABIN) $(LUA_FLAGS) $(PRECMP_LUA)   $(PRECMP_FLAGS) $(TOOLS_LUA) 

${PRECMP_DIR}/toolsall.c: ${PRECMP_DIR}/tools.c
	$(LUABIN) $(LUA_FLAGS) $(PRELOAD_LUA)  $(PRELOAD_FLAGS) ${PRECMP_DIR}/tools.h

#Descomente a linha abaixo caso deseje ativar o VERBOSE
#DEFINES=VERBOSE

SRC= ${PRECMP_DIR}/toolsall.c ${PRECMP_DIR}/tools.c lua.c

INCLUDES= ${PRECMP_DIR}
LDIR += ${OPENBUSLIB}

USE_LUA51=YES
USE_STATIC=YES
NO_SCRIPTS=YES
USE_NODEPEND=YES

LIBS += dl

.PHONY: clean-custom
clean-custom: clean
	rm -f ${PRECMP_DIR}/*.c
	rm -f ${PRECMP_DIR}/*.h

.PHONY: rebuild-custom
rebuild-custom: clean-custom rebuild

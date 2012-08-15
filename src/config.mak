PROJNAME= puts
APPNAME= ${PROJNAME}

LUABIN= ${LUA51}/bin/${TEC_UNAME}/lua5.1
LUASRC_DIR= ../lua

OPENBUSLIB= ${OPENBUS_HOME}/lib
LUA_FLAGS= -e "package.path='${OPENBUS_HOME}/lib/lua/5.1/?.lua;'..package.path"

PRECMP_DIR= ../obj/${TEC_UNAME}
PRECMP_LUA= ../lua/precompiler.lua
PRECMP_FLAGS= -p PUTS_API -o puts -l "$(LUASRC_DIR)/?.lua" -d $(PRECMP_DIR) -n

PRELOAD_LUA= ../lua/preloader.lua
PRELOAD_FLAGS= -p PUTS_API -o putspreloaded -d ${PRECMP_DIR}

PUTS_MODULES=$(addprefix tools., \
	platformid \
	config \
	build.cmake \
	build.bjam \
	build.tecmake \
	build.copy \
	build.autotools \
	build.maven \
	build.mavenimport \
	build.ant \
	build.command \
	fetch.file \
	fetch.http \
	fetch.svn \
	checklibdeps \
	platforms \
	split \
	util \
	manifest \
	path \
	search \
	deps \
	descriptor \
	compile \
	installer \
	makepack \
	remove \
	list \
	hook \
	console )

PUTS_LUA= \
$(addprefix $(LUASRC_DIR)/, \
  $(addsuffix .lua, \
    $(subst .,/, $(PUTS_MODULES))))

${PRECMP_DIR}/puts.c: $(PUTS_LUA) 
	$(LUABIN) $(LUA_FLAGS) $(PRECMP_LUA)   $(PRECMP_FLAGS) $(PUTS_MODULES) 

${PRECMP_DIR}/putspreloaded.c: ${PRECMP_DIR}/puts.c
	$(LUABIN) $(LUA_FLAGS) $(PRELOAD_LUA)  $(PRELOAD_FLAGS) -i ${PRECMP_DIR} puts.h

#Descomente a linha abaixo caso deseje ativar o VERBOSE
#DEFINES=VERBOSE

SRC= ${PRECMP_DIR}/puts.c ${PRECMP_DIR}/putspreloaded.c lua.c

INCLUDES= . ${PRECMP_DIR}
LDIR += ${OPENBUSLIB}

USE_LUA51=YES
USE_STATIC=YES
NO_SCRIPTS=YES
USE_NODEPEND=YES

LIBS += dl

ifeq "$(TEC_SYSNAME)" "Linux"
  LFLAGS = -Wl,-E
endif
ifeq "$(TEC_SYSNAME)" "SunOS"
  USE_CC= Yes
endif

.PHONY: clean-custom-obj
clean-custom-obj:
	rm -f ${PRECMP_DIR}/*.c
	rm -f ${PRECMP_DIR}/*.h

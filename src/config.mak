PROJNAME= puts
APPNAME= ${PROJNAME}

LUABIN= ${LUA51}/bin/${TEC_UNAME}/lua5.1
LUASRC_DIR= ../lua

INCDIR= ${PREFIX}/include
LIBDIR= ${PREFIX}/lib
LUA_FLAGS= -e "package.path='${LIBDIR}/lua/5.1/?.lua;'..package.path"

PRELOAD_DIR= ../obj/${TEC_UNAME}
PRELOAD_LUA= ../lua/preloader.lua

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
        make_manifest \
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

${PRELOAD_DIR}/puts.c ${PRELOAD_DIR}/puts.h: $(PRELOAD_LUA) $(PUTS_LUA)
	$(LUABIN) $(LUA_FLAGS) $(PRELOAD_LUA) -m \
		-l "$(LUASRC_DIR)/?.lua" -d $(PRELOAD_DIR) \
		-h puts.h \
		-o puts.c \
		$(PUTS_LUA)

#Descomente a linha abaixo caso deseje ativar o VERBOSE
#DEFINES=VERBOSE

SRC= ${PRELOAD_DIR}/puts.c lua.c

INCLUDES= . ${INCDIR}/luafilesystem ${PRELOAD_DIR}
LDIR += ${LIBDIR}

USE_LUA51=YES
USE_STATIC=YES
NO_SCRIPTS=YES
USE_NODEPEND=YES

LIBS += lfs

ifdef USE_STATIC
  SLIB:= $(foreach libname, $(LIBS), $(LIBDIR)/lib$(libname).a)
  LIBS:=
endif

LIBS += dl

ifeq "$(TEC_SYSNAME)" "Linux"
  LFLAGS = -Wl,-E
endif
ifeq "$(TEC_SYSNAME)" "SunOS"
  USE_CC= Yes
endif

.PHONY: clean-custom-obj
clean-custom-obj:
	rm -f ${PRELOAD_DIR}/*.c
	rm -f ${PRELOAD_DIR}/*.h

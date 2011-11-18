--TODO: deveria ser possível remover !!
BASEDIR = BASEDIR or os.getenv("HOME") .."/openbus"
assert(BASEDIR or os.getenv("HOME"), "ERROR: HOME env var not defined")

PRODAPP = PRODAPP or BASEDIR .."/lib"

SVNREPURL = SVNREPURL or "svn+https://subversion.tecgraf.puc-rio.br/engdist"
getNameVersion = function()
  return name.."-"..version
end
-- 

name = "luasocket"
version = "2.0.2"
url = SVNREPURL .. "/openbus/libs/trunk/luasocket2"
dependencies = {"lua > 5.1"}
build = {
  type = "tecmake",
  src = PRODAPP .."/".. getNameVersion() .. "/src",
  mf = { "config LUA51=../../lua-5.1.3", },
  Darwin = { mf = {"config LUA51="..PRODAPP.."/lua-5.1.3", "config BUILD_DYLIB=Yes LUA51="..PRODAPP.."/lua5.1"} },
  MacOS = { mf = {"config LUA51="..PRODAPP.."/lua-5.1.3", "config BUILD_DYLIB=Yes LUA51="..PRODAPP.."/lua5.1"} },
  SunOS510_64 = { mf = { "config LUA51="..PRODAPP.."/lua-5.1.3 ".. SUNOS64_TECMAKE_FLAGS } },
}
install_files = {
  ["../lib/${TEC_UNAME}/libluasocket.so"] = "lib",
  ["../lib/${TEC_UNAME}/libluasocket.dylib"] = "lib",
}
dev_files = {
  ["../lib/${TEC_UNAME}/libluasocket.*"] = "lib",
  ["luasocket.h"] = "include/luasocket2",
}

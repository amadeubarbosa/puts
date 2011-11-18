--TODO: deveria ser possível remover !!
BASEDIR = BASEDIR or os.getenv("HOME") .."/openbus"
assert(BASEDIR or os.getenv("HOME"), "ERROR: HOME env var not defined")

PRODAPP = PRODAPP or BASEDIR .."/lib"

SVNREPURL = SVNREPURL or "svn+https://subversion.tecgraf.puc-rio.br/engdist"
getNameVersion = function()
  return name.."-"..version
end
-- 


name = "oilall"
version = "0.5.0"
url = SVNREPURL .. "/openbus/libs/trunk/oil-0.5.0"
dependencies = {"luasocket > 2.0"}
build = {
  type = "tecmake",
  src = PRODAPP .."/"..getNameVersion().."/src",
  mf = { "oilall LUA51=../../lua-5.1.3", },
  Darwin = { mf = {"oilall LUA51="..PRODAPP.."/lua-5.1.3", "oilall BUILD_DYLIB=Yes LUA51="..PRODAPP.."/lua-5.1.3"} },
  MacOS = { mf = {"oilall LUA51="..PRODAPP.."/lua-5.1.3", "oilall BUILD_DYLIB=Yes LUA51="..PRODAPP.."/lua-5.1.3"} },
  SunOS510_64 = { mf = { "oilall LUA51="..PRODAPP.."/lua-5.1.3 ".. SUNOS64_TECMAKE_FLAGS } },
}
install_files = {
  ["../lib/${TEC_UNAME}/liboilall.so"] = "lib",
  ["../lib/${TEC_UNAME}/liboilall.dylib"] = "lib",
}
dev_files = {
  ["../lib/${TEC_UNAME}/liboilall.*"] = "lib",
  ["oilall.h"] = "include/oil-0.5.0",
}
symbolic_links = {
  ["liboilall.so"] = "lib/libluaoil.so",
  ["libluaoil.so"] = "lib/liblualuaidl.so",
  ["liblualuaidl.so"] = "lib/liblualoop.so",
}

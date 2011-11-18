--TODO: deveria ser possível remover !!
BASEDIR = BASEDIR or os.getenv("HOME") .."/openbus"
assert(BASEDIR or os.getenv("HOME"), "ERROR: HOME env var not defined")

PRODAPP = PRODAPP or BASEDIR .."/lib"

SVNREPURL = SVNREPURL or "svn+https://subversion.tecgraf.puc-rio.br/engdist"
getNameVersion = function()
  return name.."-"..version
end
-- 

name = "lua"
version = "5.1.3"
url = SVNREPURL .. "/openbus/libs/trunk/lua5.1.3"
build = {
  type = "tecmake",
  src = PRODAPP .."/".. getNameVersion() .. "/src",
  mf = { "config" },
  Darwin = { mf = {"config", "config BUILD_DYLIB=Yes", "lua"} },
  MacOS = { mf = {"config", "config BUILD_DYLIB=Yes", "lua"} },
  SunOS510_64 = { mf = { "config ".. SUNOS64_TECMAKE_FLAGS, "lua ".. SUNOS64_TECMAKE_FLAGS } },
}
install_files = {
  ["../bin/${TEC_UNAME}/lua5.1"] = "bin",
  ["../lib/${TEC_UNAME}/liblua5.1.so"] = "lib",
  ["../lib/${TEC_UNAME}/liblua5.1.dylib"] = "lib",
}
dev_files = {
  ["../bin/${TEC_UNAME}/lua5.1"] = "bin",
  ["../lib/${TEC_UNAME}/liblua5.1.*"] = "lib",
  ["../include/*"] = "include/lua5.1.3",
}
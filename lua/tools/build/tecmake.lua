-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"
local copy = require "tools.build.copy"

-- Local scope
local string = require "tools.split"

module("tools.build.tecmake", package.seeall)

function run(t, arguments)
  print("[ INFO ] Compiling package via tecmake: ".. t.name)
  local build_dir = t.build.src

  -- using per-platform tables to take the specific build actions
  local build = t.build[TEC_UNAME] or t.build[TEC_SYSNAME] or t.build
  for _, mf in ipairs(build.mf) do
    -- compiling all targets
    local build_cmd = "cd ".. build_dir .. " && ".. "tecmake"
    if arguments["rebuild"] then build_cmd = build_cmd .. " rebuild" end
    build_cmd = build_cmd .. " MF=".. mf
    local ret = os.execute(build_cmd)
    assert(ret == 0,"ERROR compiling the software ".. t.name .."")
  end

  -- installing software compiled previously
  -- defaut behaviour is the automatic installation of the tecmake generated binaries and libraries in INSTALL dirs
  if #build.mf > 0 and not t.install_files and not t.dev_files then
    util.install(t.name, build_dir .. "../bin/".. TEC_UNAME .. "/*", INSTALL.BIN )
    util.install(t.name, build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.so*", INSTALL.LIB )
    util.install(t.name, build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.dylib*", INSTALL.LIB )
--    util.install(t.name, build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.dll*", INSTALL.LIB )
    util.install(t.name.."-dev", build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.a*", INSTALL.LIB )
    util.install(t.name.."-dev", build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.so*", INSTALL.LIB )
    util.install(t.name.."-dev", build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.dylib*", INSTALL.LIB )
--    util.install(t.name.."-dev", build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.lib*", INSTALL.LIB )
--    util.install(t.name.."-dev", build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.dll*", INSTALL.LIB )
    util.install(t.name.."-dev", build_dir .. "../include/*", INSTALL.INC .. t.name )
  end

  -- re-using copy method to parse install_files, conf_files, dev_files
  copy.run(t,arguments,build_dir)
end

-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local path = require "tools.path"
local copy = require "tools.build.copy"

-- Local scope
local string = require "tools.split"

module("tools.build.tecmake", package.seeall)

function run(t, arguments)
  local nameversion = util.nameversion(t)
  util.log.info("Building",nameversion,"using tecmake driver.")
  local build_dir = t.build.src or path.pathname(config.PRODAPP,util.nameversion(t),"src")
  util.log.debug("Tecmake source directory is configured to "..build_dir)

  -- using per-platform tables to take the specific build actions
  local build = t.build[config.TEC_UNAME] or t.build[config.TEC_SYSNAME] or t.build
  for _, mf in ipairs(build.mf) do
    -- compiling all targets
    local build_cmd = "cd ".. build_dir .. " && ".. "tecmake"
    if arguments["rebuild"] then build_cmd = build_cmd .. " rebuild" end
    build_cmd = build_cmd .. " MF=".. mf
    local ret = os.execute(build_cmd)
    assert(ret == 0,"ERROR compiling the software ".. nameversion .." when performed the command '"..build_cmd.."'")
  end

  -- installing software compiled previously
  -- defaut behaviour is the automatic installation of the tecmake generated binaries and libraries in config.INSTALL dirs
  if #build.mf > 0 and not t.install_files and not t.dev_files then
    util.install(nameversion, build_dir .. "../bin/".. config.TEC_UNAME .. "/*", config.INSTALL.BIN )
    util.install(nameversion, build_dir .. "../lib/".. config.TEC_UNAME .. "/*".. t.name .."*.so*", config.INSTALL.LIB )
    util.install(nameversion, build_dir .. "../lib/".. config.TEC_UNAME .. "/*".. t.name .."*.dylib*", config.INSTALL.LIB )
--    util.install(nameversion, build_dir .. "../lib/".. config.TEC_UNAME .. "/*".. t.name .."*.dll*", config.INSTALL.LIB )
    util.install(nameversion.."-dev", build_dir .. "../lib/".. config.TEC_UNAME .. "/*".. t.name .."*.a*", config.INSTALL.LIB )
    util.install(nameversion.."-dev", build_dir .. "../lib/".. config.TEC_UNAME .. "/*".. t.name .."*.so*", config.INSTALL.LIB )
    util.install(nameversion.."-dev", build_dir .. "../lib/".. config.TEC_UNAME .. "/*".. t.name .."*.dylib*", config.INSTALL.LIB )
--    util.install(nameversion.."-dev", build_dir .. "../lib/".. config.TEC_UNAME .. "/*".. t.name .."*.lib*", config.INSTALL.LIB )
--    util.install(nameversion.."-dev", build_dir .. "../lib/".. config.TEC_UNAME .. "/*".. t.name .."*.dll*", config.INSTALL.LIB )
    util.install(nameversion.."-dev", build_dir .. "../include/*", config.INSTALL.INC .. t.name )
  end

  -- re-using copy method to parse install_files, conf_files, dev_files
  copy.run(t,arguments,build_dir)
end

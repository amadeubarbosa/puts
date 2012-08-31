-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local path = require "tools.path"
local copy = require "tools.build.copy"

-- Local scope
local string = require "tools.split"

module("tools.build.tecmake", package.seeall)

function run(t, arguments, dir)
  local nameversion = util.nameversion(t)

  local build_dir = nil
  local default_location = path.pathname(config.PRODAPP, nameversion)

  if path.is_absolute(t.build.src) then
    build_dir = t.build.src
  else
    build_dir = path.pathname(dir or default_location, t.build.src or "src")
  end

  util.log.debug("Tecmake source directory is configured to "..build_dir)

  -- tecmake variables per descriptor definitions (could be declared on its dependencies)
  local variables = ""
  if type(t.build.variables) == "table" then
    for k, v in pairs(t.build.variables) do
      variables = variables.." "..k.."="..v
    end
  end
  -- tecmake compilation rules
  for _, mf in ipairs(t.build.mf) do
    -- compiling all targets
    local build_cmd = "cd ".. build_dir .. " && ".. "tecmake"
    if arguments["rebuild"] then build_cmd = build_cmd .. " rebuild" end
    build_cmd = build_cmd .. " MF=".. mf .. variables
    local ret = os.execute(build_cmd)
    assert(ret == 0,"error compiling the software ".. nameversion .." when performed the command '"..build_cmd.."'")
  end

  -- installing software compiled previously
  -- defaut behaviour is the automatic installation of the tecmake generated binaries and libraries in config.INSTALL dirs
  if #t.build.mf > 0 and not t.install_files and not t.dev_files then
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

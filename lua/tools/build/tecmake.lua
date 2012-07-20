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
  util.log.info("Building",nameversion,"using tecmake driver.")
  -- guessing the directory with *.mak files
  local build_dir = nil
  local guess1 = dir and path.pathname(dir,"src") -- dir/src
  local guess2 = path.pathname(config.PRODAPP,nameversion,"src") -- PRODAPP/name-version/src
  if t.build.src and not t.build.src:match("^/") then -- is a relative directory
    build_dir = path.pathname(guess1 or guess2, t.build.src)
  else
    build_dir = t.build.src or guess1 or guess2
  end
  util.log.debug("Tecmake source directory is configured to "..build_dir)

  -- using per-platform tables to take the specific build actions
  local build = t.build[config.TEC_UNAME] or t.build[config.TEC_SYSNAME] or t.build
  for _, mf in ipairs(build.mf) do
    -- compiling all targets
    local build_cmd = "cd ".. build_dir .. " && ".. "tecmake"
    if arguments["rebuild"] then build_cmd = build_cmd .. " rebuild" end
    build_cmd = build_cmd .. " MF=".. mf
    local ret = os.execute(build_cmd)
    assert(ret == 0,"error compiling the software ".. nameversion .." when performed the command '"..build_cmd.."'")
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

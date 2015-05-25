-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local copy = require "tools.build.copy"
local path = require "tools.path"

module("tools.build.command", package.seeall)

function run(t, arguments)
  local nameversion = util.nameversion(t)
  
  local build_dir = nil
  local default_location = path.pathname(config.PRODAPP, nameversion)

  if path.is_absolute(t.build.src) then
    build_dir = t.build.src
  else
    build_dir = path.pathname(t.directory or default_location, t.build.src or "")
  end

  if not t.build.cmd then
    util.log.error("No build command provided to compile", nameversion,
      "on", config.TEC_UNAME, "neither", config.TEC_SYSNAME, "platforms.")
    return nil
  end

  -- tecmake variables per descriptor definitions (could be declared on its dependencies)
  local variables = ""
  if type(t.build.variables) == "table" then
    for k, v in pairs(t.build.variables) do
      variables = variables.." "..k.."="..v.." && "
    end
  end

  local command = t.build.cmd

  -- Adding arguments
  if arguments["rebuild"] and t.build.rebuild then
    command = command .. " " .. t.build.rebuild
  end

  if arguments["verbose"] and t.build.verbose then
    command = command .. " " .. t.build.verbose
  end
  
  if t.build.arguments then
    command = command .. " " .. t.build.arguments
  end

  build_cmd = "cd " .. build_dir .. " && " .. variables .. " " .. command

  local ret = os.execute(build_cmd)
  assert(ret == 0,"error compiling the software ".. nameversion .." when performed the command '"..build_cmd.."'")

  -- re-using copy method to parse install_files, conf_files, dev_files
  copy.run(t,arguments,build_dir)
end

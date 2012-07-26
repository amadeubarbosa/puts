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

  local build_table = t.build[config.TEC_UNAME] or t.build[config.TEC_SYSNAME] or t.build

  if not build_table.cmd then
    util.log.error("No build command provided to compile", nameversion,
      "in", config.TEC_UNAME, "or", config.TEC_SYSNAME, "platforms.")
    return nil
  end

  command = build_table.cmd

  -- Adding arguments
  if not arguments["rebuild"] and build_table.rebuild then
    command = command .. " " .. build_table.rebuild
  end

  if not arguments["verbose"] and build_table.verbose then
    command = command .. " " .. build_table.verbose
  end
  
  if build_table.arguments then
    command = command .. " " .. build_table.arguments
  end

  build_cmd = "cd " .. build_dir .. " && " .. command

  local ret = os.execute(build_cmd)
  assert(ret == 0,"error compiling the software ".. nameversion .." when performed the command '"..build_cmd.."'")

  -- re-using copy method to parse install_files, conf_files, dev_files
  copy.run(t,arguments,build_dir)
end

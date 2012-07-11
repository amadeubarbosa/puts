-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local copy = require "tools.build.copy"
local path = require "tools.path"

module("tools.build.command", package.seeall)

function run(t, arguments)
  local nameversion = util.nameversion(t)
  
  util.log.info("Building",nameversion,"using command driver.")
  local build_dir = t.build.src or path.pathname(config.PRODAPP,nameversion)
  local build_table = t.build[config.TEC_UNAME] or t.build[config.TEC_SYSNAME] or t.build

  if not build_table.cmd then
    util.log.warning(nameversion..[[ has no build command provided for ']]..config.TEC_UNAME..[[' platforms. Skipping.]])
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

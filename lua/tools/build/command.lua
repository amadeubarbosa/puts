-- Basic variables (global vars are in upper case)
require "tools.config"
local copy = require "tools.build.copy"


module("tools.build.command", package.seeall)

function run(t, arguments)
  print("[ INFO ] Importing package via command: ".. t.name)
  local build_dir = t.build.src
  local build_table = t.build
  if not build_dir:match("/$") then build_dir = build_dir.."/" end

  if not build_table.cmd then
    print("ERROR 'cmd' parameter is missing.")
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
  assert(ret == 0,"ERROR compiling the software ".. t.name .."")

  -- re-using copy method to parse install_files, conf_files, dev_files
  copy.run(t,arguments,build_dir)
end

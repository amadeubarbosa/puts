-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local copy = require "tools.build.copy"
local path = require "tools.path"

module("tools.build.ant", package.seeall)

function run(t, arguments)
  local nameversion = util.nameversion(t)
  util.log.info("Building",nameversion,"using ant driver.")
  local build_dir = t.build.src or path.pathname(config.PRODAPP,util.nameversion(t))

  -- Making command
  local ant_cmd =  "ant "
  if arguments["rebuild"] then
    ant_cmd = ant_cmd .. "clean "
  end
  ant_cmd = ant_cmd .. (t.build.target or "")

  -- Adding arguments
  local ant_args = "" 
  if not arguments["verbose"] then 
    ant_args = ant_args .. " -q " 
  end

  build_cmd = "cd " .. build_dir .. " && " .. ant_cmd .. ant_args

  local ret = os.execute(build_cmd)
  -- assert ensure that we could continue
  assert(ret == 0,"ERROR compiling the software ".. nameversion .." when performed the command '"..build_cmd.."'")

  -- re-using copy method to parse install_files, conf_files, dev_files
  copy.run(t,arguments,build_dir)
end


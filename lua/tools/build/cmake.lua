-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local copy = require "tools.build.copy"

local platforms = require "tools.platforms"
local plat = platforms[config.TEC_SYSNAME]

module("tools.build.cmake", package.seeall)

function run(t, arguments)
  local nameversion = util.nameversion(t)
  util.log.info("Building",nameversion,"using cmake driver.")
  util.log.info("Creating Makefiles with CMake for: ".. nameversion)

  os.execute(plat.cmd.mkdir .. config.TMPDIR)
  
  local build_dir = config.TMPDIR

  -- Making command
  local cmake_cmd = "cd " .. build_dir .. " && " .. "cmake " .. t.build.src

  local build = t.build[config.TEC_UNAME] or t.build[config.TEC_SYSNAME] or t.build
  for n,v in pairs(build.definitions) do
     cmake_cmd = cmake_cmd.." -D"..n.."="..v
  end

  print(t.build.src)

  if arguments["rebuild"] then
     util.log.info("Rebuild selected - removing content from: ".. build_dir)
     os.execute(plat.cmd.rm .. build_dir .. '/*')
  end
  
  local ret = os.execute(cmake_cmd)
  -- assert ensure that we could continue
  assert(ret == 0,"ERROR Generating Makefile".. nameversion .."")

  local make_cmd = plat.cmd.make .. (t.build.target or "")

  -- Adding arguments
  local make_args = "" 
  if not arguments["verbose"] then 
    make_args = make_args .. "  " 
  end

  build_cmd = "cd " .. build_dir .. " && " .. make_cmd .. make_args

  ret = os.execute(build_cmd)
  -- assert ensure that we could continue
  assert(ret == 0,"ERROR compiling the software ".. nameversion .." when performed the command '"..build_cmd.."'")
  
  -- re-using copy method to parse install_files, conf_files, dev_files
  copy.run(t,arguments,build_dir)
end


-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"
local copy = require "tools.build.copy"

local platforms = require "tools.platforms"
local plat = platforms[TEC_SYSNAME]

module("tools.build.cmake", package.seeall)

function run(t, arguments)
  print("[ INFO ] Creating Makefiles with CMake for: ".. t.name)

  os.execute(plat.cmd.mkdir .. TMPDIR)
  
  local build_dir = TMPDIR

  -- Making command
  local cmake_cmd = "cd " .. build_dir .. " && " .. "cmake " .. t.build.src

  print(t.build.src)

  if arguments["rebuild"] then
     print("[ INFO ] Rebuild selected - removing content from: ".. build_dir)
     os.execute(plat.cmd.rm .. build_dir .. '/*')
  end
  
  local ret = os.execute(cmake_cmd)
  -- assert ensure that we could continue
  assert(ret == 0,"ERROR Generating Makefile".. t.name .."")

  local make_cmd = plat.cmd.make .. (t.build.target or "")

  -- Adding arguments
  local make_args = "" 
  if not arguments["verbose"] then 
    make_args = make_args .. "  " 
  end

  build_cmd = "cd " .. build_dir .. " && " .. make_cmd .. make_args

  ret = os.execute(build_cmd)
  -- assert ensure that we could continue
  assert(ret == 0,"ERROR compiling the software ".. t.name .."")

  -- re-using copy method to parse install_files, conf_files, dev_files
  copy.run(t,arguments,build_dir)
end


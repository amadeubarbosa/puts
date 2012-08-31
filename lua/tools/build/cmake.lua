-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local path = require "tools.path"
local copy = require "tools.build.copy"

local platforms = require "tools.platforms"
local plat = platforms[config.TEC_SYSNAME]

module("tools.build.cmake", package.seeall)

function run(t, arguments, dir)
  local nameversion = util.nameversion(t)
  util.log.info("Creating Makefiles with CMake for: ".. nameversion)
  
  local src_dir = nil
  local default_location = path.pathname(config.PRODAPP, nameversion)

  if t.build.src and path.is_absolute(t.build.src) then
    src_dir = t.build.src
  else
    src_dir = path.pathname(dir or default_location, t.build.src or "")
  end

  local build_dir = path.pathname(src_dir,"build")
  os.execute(plat.cmd.mkdir .. build_dir)

  -- Making command
  local cmake_cmd = "cd " .. build_dir .. " && " .. "cmake .."

  for n,v in pairs(t.build.variables or {}) do
     cmake_cmd = cmake_cmd.." -D"..n.."="..v
  end

  print(src_dir)

  if arguments["rebuild"] then
     util.log.info("Rebuild selected - removing content from: ".. build_dir)
     os.execute(plat.cmd.rm .. build_dir .. '/*')
  end
  
  local ret = os.execute(cmake_cmd)
  -- assert ensure that we could continue
  assert(ret == 0,"error generating Makefile".. nameversion .."")

  local make_cmd = plat.cmd.make .. (t.build.target or "")

  -- Adding arguments
  local make_args = "" 
  if not arguments["verbose"] then 
    make_args = make_args .. "  " 
  end

  build_cmd = "cd " .. build_dir .. " && " .. make_cmd .. make_args

  ret = os.execute(build_cmd)
  -- assert ensure that we could continue
  assert(ret == 0,"error compiling the software ".. nameversion .." when performed the command '"..build_cmd.."'")
  
  -- re-using copy method to parse install_files, conf_files, dev_files
  copy.run(t,arguments,build_dir)
end


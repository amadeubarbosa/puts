-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local copy = require "tools.build.copy"
local util = require "tools.util"
local path = require "tools.path"

module("tools.build.maven", package.seeall)

function run(t, arguments)
  local nameversion = util.nameversion(t)

  local build_dir = nil
  local default_location = path.pathname(config.PRODAPP, nameversion)

  if path.is_absolute(t.build.src) then
    build_dir = t.build.src
  else
    build_dir = path.pathname(t.directory or default_location, t.build.src or "")
  end

  -- Making command
  local maven_cmd =  "mvn "

  -- maven variables 
  if t.build and type(t.build.variables) == "table" then
    local variables = ""
    for k, v in pairs(t.build.variables) do
      variables = variables.." -D"..k.."="..v
    end
    maven_cmd = maven_cmd .. variables
  end

  if arguments["rebuild"] then
    maven_cmd = maven_cmd .. "clean "
  end
  maven_cmd = maven_cmd .. "install "

  -- Adding arguments
  local maven_args = " -DskipTests " 
  if not arguments["verbose"] then 
    maven_args = maven_args .. "-q " 
  end

  build_cmd = "cd " .. build_dir .. " && " .. maven_cmd .. maven_args

  local ret = os.execute(build_cmd)
  -- assert ensure that we could continue
  assert(ret == 0,"error compiling the software ".. nameversion .." when performed the command '"..build_cmd.."'")
  
  -- re-using copy method to parse install_files, conf_files, dev_files
  copyDependence(t,arguments,build_dir)
  copy.run(t,arguments,build_dir)
end

function copyDependence(t,arguments,build_dir)
  local nameversion = util.nameversion(t)
  local maven_cmd = "mvn "
  maven_cmd = maven_cmd .. "dependency:copy-dependencies "
  maven_args = "-DincludeScope=runtime"

  -- Adding arguments
  if not arguments["verbose"] then
    maven_args = maven_args .. " -Dsilent=true "
  end

  build_cmd = "cd " .. build_dir .. " && " .. maven_cmd .. maven_args

  local ret = os.execute(build_cmd)
  assert(ret == 0, "error on mvn dependency:copy-dependencies of " .. nameversion)
end 

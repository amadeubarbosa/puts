-- Basic variables (global vars are in upper case)
require "tools.config"
local copy = require "tools.build.copy"


module("tools.build.maven", package.seeall)

function run(t, arguments)
  print("[ INFO ] Compiling package via maven: ".. t.name)
  local build_dir = t.build.src

  -- Making command
  local maven_cmd =  "mvn "
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
  assert(ret == 0,"ERROR compiling the software ".. t.name .."")

  -- re-using copy method to parse install_files, conf_files, dev_files
  copyDependence(t,arguments,build_dir)
  copy.run(t,arguments,build_dir)
end

function copyDependence(t,arguments,build_dir)
  local maven_cmd = "mvn "
  maven_cmd = maven_cmd .. "dependency:copy-dependencies "
  maven_args = "-DincludeScope=runtime"

  -- Adding arguments
  if not arguments["verbose"] then
    maven_args = maven_args .. " -Dsilent=true "
  end

  build_cmd = "cd " .. build_dir .. " && " .. maven_cmd .. maven_args

  local ret = os.execute(build_cmd)
  assert(ret == 0, "ERRO copying-dependencies" .. t.name)
end 

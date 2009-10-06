-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"
local copy = require "tools.build.copy"
local maven = require "tools.build.maven"

-- Local scope
local string = require "tools.split"
local platforms = require "tools.platforms"
local myplat = platforms[TEC_SYSNAME]

module("tools.build.mavenimport", package.seeall)

function run(t, arguments)
  print("[ INFO ] Importing package via maven: ".. t.name)
  local build_dir = t.build.src
  if not build_dir:match("/$") then build_dir = build_dir.."/" end

  -- Making command
  local maven_cmd =  "mvn "
  maven_cmd = maven_cmd .. "install:install-file "

  -- Adding arguments
  local maven_args = "-DskipTests " 
  if not arguments["verbose"] and not arguments["v"] then 
    maven_args = maven_args .. "-q " 
  end

  assert(type(t.parameters)=="table")
  for file, props in pairs(t.parameters) do
    local repoinstall =
      " -DgroupId="    .. props.groupId ..
      " -DartifactId=" .. props.artifactId ..
      " -Dversion="    .. props.version .. 
      " -Dpackaging="  .. "jar" ..
      " -Dfile="       .. file				
				
    if props.pomFile then
      repoinstall = repoinstall .. " -DpomFile=" .. props.pomFile
    end

    build_cmd = "cd " .. build_dir .. " && " .. maven_cmd .. 
      maven_args .. repoinstall
    local ret = os.execute(build_cmd)
    -- assert ensure that we could continue
    assert(ret == 0,"ERROR compiling the software ".. t.name ..
      " when it tried to install the file: ".. file .. 
      " in the maven repository.")
  end

    -- re-using copy method to parse install_files, conf_files, dev_files
    copy.run(t,arguments,build_dir)
end

-- Basic variables (global vars are in upper case)
require "tools.config"
local copy = require "tools.build.copy"
local maven = require "tools.build.maven"

module("tools.build.mavenimport", package.seeall)

function run(t, arguments)
  local nameversion = util.nameversion(t)
  print("[ INFO ] Importing package via mavenimport: ".. nameversion)
  local build_dir = t.build.src

  -- Making command
  local maven_cmd =  "mvn "
  maven_cmd = maven_cmd .. "install:install-file "

  -- Adding arguments
  local maven_args = "-DskipTests " 
  if not arguments["verbose"] then 
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
    assert(ret == 0,"ERROR compiling the software ".. nameversion ..
      " when it tried to install the file: ".. file .. 
      " in the maven repository.")
  end

    -- re-using copy method to parse install_files, conf_files, dev_files
    copy.run(t,arguments,build_dir)
end

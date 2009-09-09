-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"
local copy = require "tools.build.copy"

-- Local scope
local string = require "tools.split"
local platforms = require "tools.platforms"
local myplat = platforms[TEC_SYSNAME]

module("tools.build.maven", package.seeall)

function run(t, arguments)
	print("[ INFO ] Compiling package via maven: ".. t.name)
	local build_dir = t.build.src
	if not build_dir:match("/$") then build_dir = build_dir.."/" end

	-- Making command
	local maven_cmd =  "mvn "
	if not t.build.legacymode then
		if arguments["rebuild"] then
			maven_cmd = maven_cmd .. "clean "
		end
		maven_cmd = maven_cmd .. "install "

		-- Adding arguments
		local maven_args = " -DskipTests " 
		if not arguments["verbose"] and not arguments["v"] then 
			maven_args = maven_args .. "-q " 
		end

		build_cmd = "cd " .. build_dir .. " && " .. maven_cmd .. maven_args

		local ret = os.execute(build_cmd)
		-- assert ensure that we could continue
		assert(ret == 0,"ERROR compiling the software ".. t.name .."")
	end
	-- Triggers after the compilation
	if t.maven_post_compile then
		assert(type(t.maven_post_compile)=="table")
		for file, props in pairs(t.maven_post_compile) do
			local repoinstall = " install:install-file -DskipTests -DgroupId=" .. props.groupId ..
					" -DartifactId=".. props.artifactId ..
					" -Dversion=" .. props.version .. 
					" -Dpackaging=jar -Dfile=" .. file
			local ret = os.execute("cd ".. build_dir .." && ".. maven_cmd .. repoinstall)
			-- assert ensure that we could continue
			assert(ret == 0,"ERROR compiling the software ".. t.name ..
				" when it tried to install the file: ".. file .. 
				" in the maven repository.")
		end
	end
	-- re-using copy method to parse install_files, conf_files, dev_files
	copy.run(t,arguments,build_dir)
end


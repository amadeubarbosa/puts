-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"
local copy = require "tools.build.copy"

-- Local scope
local string = require "tools.split"
local platforms = require "tools.platforms"
local myplat = platforms[TEC_SYSNAME]

module("tools.build.ant", package.seeall)

function run(t, arguments)
	print("[ INFO ] Compiling package via ant: ".. t.name)
	local build_dir = t.build.src
	if not build_dir:match("/$") then build_dir = build_dir.."/" end

	-- Making command
	local ant_cmd =  "ant "
	if arguments["rebuild"] then
		ant_cmd = ant_cmd .. "clean "
	end
	ant_cmd = ant_cmd .. (t.build.target or "")

	-- Adding arguments
	local ant_args = "" 
	if not arguments["verbose"] and not arguments["v"] then 
		ant_args = ant_args .. "-q " 
	end

	build_cmd = "cd " .. build_dir .. " && " .. ant_cmd .. ant_args

	local ret = os.execute(build_cmd)
	-- assert ensure that we could continue
	assert(ret == 0,"ERROR compiling the software ".. t.name .."")

	-- re-using copy method to parse install_files, conf_files, dev_files
	copy.run(t,arguments,build_dir)
end


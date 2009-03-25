require "tools.config"
local util = require "tools.util"

-- Local scope
local string = require "tools.split"
local platforms = require "tools.platforms"
local myplat = platforms[TEC_SYSNAME]

module("tools.build.copy", package.seeall)

function run(t,arguments,build_dir)
	assert(type(t) == "table")
	-- we assume a default build_dir pointing to PRODAPP
	if not build_dir then
		build_dir = PRODAPP .."/".. t.name .."/"
		print(" [info] Assuming build_dir as '"..build_dir.."' for pkg: ".. t.name)
	end
	-- fetching and unpacking
	if t.source then
		util.fetch_and_unpack(t.name, t.source, build_dir)
	end
	-- copying files described on packages table
	if t.install_files then
		for orig, dest in pairs(t.install_files) do
			-- if absolute path we assume that you know where get the files
			if orig:match("^/") then build_dir = "" end
			util.install(t.name, build_dir .. orig, dest)
		end
	end
	-- copying files related to configuration with '-conf' suffix
	if t.conf_files then
		for orig, dest in pairs(t.conf_files) do
			-- if absolute path we assume that you know where get the files
			if orig:match("^/") then build_dir = "" end
			util.install(t.name.."-conf", build_dir.. orig, dest)
		end
	end
	-- temp behaviour, future: each package as a <name>.desc and <name>.template
	-- important for configuration procedure in installation time
	if t.conf_template then
		local content = assert(io.open(t.conf_template,"r")):read("*a")
		assert(io.open(PKGDIR.."/"..t.name..".template", "w")):write(content)
	end
	-- copying files to special packages with '-dev' suffix
	if t.dev_files then
		for orig, dest in pairs(t.dev_files) do
			-- if absolute path we assume that you know where get the files
			if orig:match("^/") then build_dir = "" end
			util.install(t.name.."-dev", build_dir.. orig, dest)
		end
	end
	-- linking files described on packages table
	if t.symbolic_links then
		for orig, linkpath in pairs(t.symbolic_links) do
			util.link(t.name, orig, linkpath)
		end
	end
end
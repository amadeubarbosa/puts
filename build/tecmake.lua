-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"
local copy = require "tools.build.copy"

-- Local scope
local string = require "tools.split"
local platforms = require "tools.platforms"
local myplat = platforms[TEC_SYSNAME]

module("tools.build.tecmake", package.seeall)

function run(t, arguments)
	print(" [info] Compiling package via tecmake: ".. t.name)
	local build_dir = t.build.src
	for _, mf in ipairs(t.build.mf) do
		-- compiling all targets
		local build_cmd = "cd ".. build_dir .. "; ".. "tecmake MF=".. mf
		if arguments["rebuild"] then build_cmd = build_cmd .. " rebuild" end
		local ret = os.execute(build_cmd)
		assert(ret == 0,"ERROR compiling the software ".. t.name .."")
	end

	-- installing software compiled previously
	-- defaut behaviour is the automatic installation on INSTALL dirs
	if #t.build.mf > 0 and not t.install_files and not t.dev_files then
		util.install(t.name, build_dir .. "../bin/".. TEC_UNAME .. "/*", INSTALL.BIN )
		util.install(t.name, build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.so*", INSTALL.LIB )
		util.install(t.name, build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.dylib*", INSTALL.LIB )
--		util.install(t.name, build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.dll*", INSTALL.LIB )
		util.install(t.name.."-dev", build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.a*", INSTALL.LIB )
		util.install(t.name.."-dev", build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.so*", INSTALL.LIB )
		util.install(t.name.."-dev", build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.dylib*", INSTALL.LIB )
--		util.install(t.name.."-dev", build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.lib*", INSTALL.LIB )
--		util.install(t.name.."-dev", build_dir .. "../lib/".. TEC_UNAME .. "/*".. t.name .."*.dll*", INSTALL.LIB )
		util.install(t.name.."-dev", build_dir .. "../include/*", INSTALL.INC .. t.name )
	end

	-- re-using copy method to parse install_files, dev_files
	copy.run(t,arguments,build_dir)
end

-- Saving important variables from LuaVM
local package_path = package.path
local package_cpath = package.cpath

package.path = "?.lua;../?.lua;" .. package.path

require "tools.config"
local string = require "tools.split"
local platforms = require "tools.platforms"
local util = require "tools.util"

module("tools.check-lib-deps",package.seeall)

local checker = {}

-- Checks libraries dependencies in an OpenBus installation
function checker:libraries_deps(openbus_home)
	assert(type(openbus_home) == "string", "ERROR: Check libraries function receives a nil parameter.")

	local function rollback()
		-- Recovering important variables to LuaVM
		package.path = package_path
		package.cpath = package_cpath
	end
	
	local msg = "[ checker:libraries_deps ] "
	local libpath = openbus_home.."/libpath/"..TEC_UNAME

	local myplat = platforms[TEC_SYSNAME]
	assert(type(myplat.dylibext) == "string", "ERROR: Missing dynamic libraries extension information on 'platforms'.")

	print(msg.."assuming that libraries has '"..myplat.dylibext.."' extension.")
	print(msg.."assuming OpenBus installation: "..openbus_home)
	print(msg.."assuming additional path for libs: "..libpath)
	package.cpath = package.cpath .. ";"..
		-- posix module uses an unusual lua_open name!
		libpath .."/libl?."..myplat.dylibext..";"..
		-- others openbus libs uses lib<name>.<dylibext>
		libpath .."/lib?."..myplat.dylibext..";"

	-- trying load the posix module
	local posix = require "posix"

	local misses = {}
	local libpath_files = posix.dir(libpath)
	if not libpath_files then
		rollback()
		return nil, {}, "ERROR: Invalid OpenBus path for your platform."
	end
	-- testing all dynamic library files
	for _,file in ipairs(libpath_files) do
		local fullname = libpath.."/"..file
		if fullname:find("."..myplat.dylibext) then
			--print("DEBUG: looking for "..file.." dynamic dependencies")
			local miss = myplat:missing_libraries(fullname)
			-- parse plat format to represent the unknown symbols
			-- good for more information about the miss library

			-- print("DEBUG: all unknown symbols:")
			-- s = platforms[myplat]:unknown_symbols(fullname)
			-- print(s)

			if miss then
				-- second check: trying use openbus libpath (that can being installed!!)
				local willbefine = myplat:search_ldlibpath(file,libpath)
				if not willbefine then
					table.insert(misses,{name = file, miss = miss})
				end
			end
		end
	end

	-- return nil if we got misses
	if #misses > 0 then
		return nil, misses, "ERROR: Check if your system variable for dynamic "..
		                    "libraries is right."
	else
		print(msg.."done!")
		return true
	end
end

-- SAMPLE of a main function that could receive OPENBUS_HOME by arg table
function checker:start(openbus_home)
	-- Call the checker
	local ok, misses, errmsg = self:libraries_deps(openbus_home)

	-- Presents the results
	if not ok then
		for i,t in ipairs(misses) do
			if #t.miss > 0 then
				print("   ERROR: missing for ",t.name)
				table.foreach(t.miss,print)
			end
		 end
		return nil, errmsg
	else
		return true, "Library dependencies check DONE."
	end
end

--------------------------------------------------------------------------------
-- Main code -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Allow be loaded from console
--~ if arg then
	--~ -- Parsing arguments
	--~ local arguments = util.parse_args(arg,[[
		--~ --help                   : show this help
		--~ --openbus=directory      : use 'directory' as OpenBus installation ]],true)
	--~ print("Searching missing dependencies...")
	--~ assert(start(arguments.openbus or os.getenv("OPENBUS_HOME")))
--~ end
return checker

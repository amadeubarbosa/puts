package.path = "?.lua;../?.lua;" .. package.path

local string = require "tools.split"
local platforms = require "tools.platforms"

package.path = ""

local posix = require "posix"

assert(os.getenv("OPENBUS_HOME"), "OPENBUS_HOME env var not defined")
assert(os.getenv("TEC_SYSNAME"), "TEC_SYSNAME env var not defined")

local OPENBUS_HOME = os.getenv("OPENBUS_HOME")
-- how tecmake identifies my platform
local myplat = os.getenv("TEC_SYSNAME")

-- parse plat format to represent the unknown symbols
-- print("DEBUG: all symbols:")
-- s = platforms[myplat]:unknown_symbols(FILE)
-- print(s)

misses = {}
libpath = posix.dir(OPENBUS_HOME.."/libpath")
for _,file in ipairs(libpath) do
	if file:find(".so") then
		-- check against the dynamic libraries
		print("DEBUG: looking for "..file.." dynamic dependencies")
		local miss = platforms[myplat]:missing_libraries(file)
		if miss then
			table.insert(misses,{name = file, miss = miss})
		end
	end
end

print("DEBUG: missing dependencies")
for name,miss in pairs(misses) do
	print(" missing for ",name)
	table.foreach(miss,print)
end

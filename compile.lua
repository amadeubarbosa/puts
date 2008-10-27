#!/usr/bin/env lua5.1
package.path = "?.lua;../?.lua;" .. package.path

-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"

-- Local scope
local string = require "tools.split"
local platforms = require "tools.platforms"
local myplat = platforms[TEC_SYSNAME]
local default_assert = assert

--------------------------------------------------------------------------------
-- Parsing arguments, filtering descriptions and reaching basic requests -------
--------------------------------------------------------------------------------
-- Parsing arguments
assert(arg,"Table arg missing! This program should be loaded from console.")
local arguments = {}
local patt="%-?%-?(%w+)(=?)(.*)"
local usage_msg=[[ Usage: ]]..arg[0]..[[ OPTIONS
	Valid OPTIONS:
	--help                   : show this help
	--verbose                : turn ON the VERBOSE mode (show the system commands)
	--basesoft=filename      : use the 'filename' as input for basic
	                           softwares with autotools semantic (i.e: openssl)
	--packages=filename      : use the 'filename' as input for packages
	                           with tecmake semantic (i.e: lua5.1, openbus-core)
	--rebuild                : changes the default rule for tecmake rebuild if
	                           already compiled
	--force                  : forces the compile and install (i.e: you want
	                           re-generate some library even it's installed
	                           already = to debug or devel purpose)
	--list                   : list all package names from description files. When
	                           '--select' is used, it'll confirm the selection.
	--select="pkg1 pkg2 ..." : choose which packages to compile and install    ]]

for i,param in ipairs(arg) do
	local opt,_,value = string.match(param,patt)
	if opt == "h" or opt == "help" then
		print(usage_msg)
		os.exit(0)
	end
	if opt and value then
		if opt == "select" then
			-- selecting packages to build with multiple '--select' support
			if not arguments[opt] then arguments[opt] = {} end
			for _,pkg in ipairs({value:split("[^%s]+")}) do
				arguments[opt][pkg] = pkg
			end
		else
			arguments[opt] = value
		end
	end
end

print("\nINFO: We are going to install full openbus dependencies on \
".. INSTALL.TOP .." and temporary install directories \
(for autotools based packages) on ".. TMPDIR .." .\n")

-- Loading basesoft and package descriptions tables
assert(loadfile(arguments["basesoft"] or DEPLOYDIR .."/basesoft.desc"))()
assert(loadfile(arguments["packages"] or DEPLOYDIR .."/packages.desc"))()

-- Filtering the descriptions tables with '--select' arguments
-- preparing the tables to provide t[pkg_name] fields
function rehashByName(mytable)
	-- REMEMBER: loop.ordered.set is better but insert loop dependency
	for i,t in ipairs(mytable) do
		mytable[t.name] = t
	end
end

rehashByName(basesoft)
rehashByName(packages)

-- real filtering
local newbasesoft = {}
local newpackages = {}
if arguments["select"] then
	for pkg,_ in pairs(arguments["select"]) do
		-- cloning the references in new tables
		if basesoft[pkg] then
			table.insert(newbasesoft,basesoft[pkg])
		end
		if packages[pkg] then
			table.insert(newpackages,packages[pkg])
		end
	end
	-- replace the main references to cloned tables
	if #newbasesoft > 0 then basesoft = newbasesoft end
	if #newpackages > 0 then packages = newpackages end
end

-- Listing packages when '--list' arguments
if arguments["list"] then
	print "INFO: Available basesoft to compile and install:"
	for _, t in ipairs(basesoft) do
		print("\t"..t.name)
	end
	print "\nINFO: Available packages to compile and install:"
	for _, t in ipairs(packages) do
		print("\t"..t.name)
	end
	os.exit(0)
end

--------------------------------------------------------------------------------
-- Useful functions (overloading, install and link) ----------------------------
--------------------------------------------------------------------------------

-- Setting verbose level if requested
if arguments["verbose"] or arguments["v"] then
	util.verbose(1)
end

--------------------------------------------------------------------------------
-- Main code -------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Creating the build environment to create .tar.gz (later) from it
os.execute("mkdir -p ".. INSTALL.TOP)
os.execute("mkdir -p ".. INSTALL.LIB)
os.execute("mkdir -p ".. INSTALL.BIN)
os.execute("mkdir -p ".. INSTALL.INC)
os.execute("mkdir -p ".. TMPDIR)
os.execute("mkdir -p ".. PKGDIR)
os.execute(FETCH_CMD)

-- Cleaning the temp dir to execute install rules of autotools softwares
os.execute("rm -rf "..TMPDIR.."/*")

-- Parsing basesoft and compiling+installing on WORKDIR environment
function parseDescriptions(desc)
	for _, t in ipairs(desc) do
		print "----------------------------------------------------------------------"
		-- hack when no build is provided, to _always_ copy install_files , dev_files
		if not t.build then
			t.build = { type = "copy" }
		end

		assert(t.build.type, "ERROR: build.type is missing for package: "..t.name)
		-- loading specific build methods
		ok, build_type = pcall(require, "tools.build." .. t.build.type)
		assert(ok and type(build_type) == "table","ERROR: failed initializing "..
		                    "build back-end for build type: '".. t.build.type ..
		                    "' for package: ".. t.name)

		-- starting build methods
		build_type.run(t,arguments)

		print " [info] Done!"
		print "----------------------------------------------------------------------"
	end
end

parseDescriptions(basesoft)
parseDescriptions(packages)

-- Cleaning environment
os.execute("rm -rf ".. TMPDIR)
--~ I shouldn't need this!!
--~ os.execute("cd ".. INSTALL.TOP.. "; unlink lib/lib")
--~ os.execute("cd ".. INSTALL.TOP.. "; unlink include/include")
--~ os.execute("cd ".. INSTALL.TOP.. "; unlink core/services/services")

-- Closing install log files
util.close_log()

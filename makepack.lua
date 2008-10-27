#!/usr/bin/env lua5.1
package.path = "?.lua;../?.lua;" .. package.path

-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"

-- Parsing arguments
assert(arg,"Table arg missing! This program should be loaded from console.")
local arguments = {}
local patt="%-?%-?(%w+)(=?)(.*)"
local usage_msg=[[ Usage: ]]..arg[0]..[[ OPTIONS
	Valid OPTIONS:
	--help                   : show this help
	--verbose                : turn ON the VERBOSE mode (show the system commands)
	--profile=filename       : use the 'filename' as input for profile with the
	                           list of packages to packaging
	--arch=tecmake_arch      : specifies the arch based on tecmake way. Use 'all'
	                           to pack all supported architectures  ]]

if not (arg[1]) then print(usage_msg) ; os.exit(1) end

for i,param in ipairs(arg) do
	local opt,_,value = string.match(param,patt)
	if opt == "h" or opt == "help" then
		print(usage_msg)
		os.exit(1)
	end
	if opt and value then
		arguments[opt] = value
	end
end

-- Overloading the os.execute to dummy verbose
if arguments["verbose"] or arguments["v"] then
	util.verbose(1)
end

assert(arguments["profile"],"Missing argument --profile!")
assert(arguments["arch"] or TEC_UNAME,"Missing argument --arch and not exist TEC_UNAME env!")
arguments["arch"] = arguments["arch"] or TEC_UNAME

function pack(arch,profile)
	-- Re-setting variables with arch values
	PKGDIR = WORKDIR .."/pkgfiles/".. arch
	INSTALL.BIN = INSTALL.TOP .."/bin/".. arch .."/"
	INSTALL.LIB = INSTALL.TOP .."/libpath/".. arch .."/"

	tarball_files = ""
	local add = function(f)
		if f then
			str = f:read("*a"):gsub("\n"," "):gsub("${TEC_UNAME}",arch)
			tarball_files = tarball_files .. str
			f:close()
		end
	end

	local _,name = profile:match("(.*)/(.*)") --extracts name from "dir/name.profile"
	name = name or profile                    --could nil only if "name.profile"
	name = name:gsub(".profile","")              --deletes the suffix ".profile"

	print "----------------------------------------------------------------------"
	print(" [info] Generating the tarball for arch:".. arch .." profile:".. name)
	local file = assert(io.open(profile,"r") or 
			io.open(name..".profile","r") or 
			io.open(DEPLOYDIR .."/profiles/".. name,"r") or 
			io.open(DEPLOYDIR .."/profiles/".. name ..".profile","r"))
	local l = file:lines()
	repeat
		p = l()
		if p then
			-- files
			add(io.open(PKGDIR.."/"..p..".files","r"))
			-- links
			add(io.open(PKGDIR.."/"..p..".links","r"))
		end
	until (p == nil)

	local tar_cmd = "cd ".. INSTALL.TOP ..";"
	tar_cmd = tar_cmd .. "tar --exclude '.svn'"
	tar_cmd = tar_cmd .. " -czf ../openbus-".. name .."_".. arch .. ".tar.gz "
	tar_cmd = tar_cmd .. tarball_files
	os.execute(tar_cmd)
	print " [info] Done!"
	print "----------------------------------------------------------------------"
end

-- MAIN
if arguments["arch"] ~= "all" then
	pack(arguments["arch"],arguments["profile"])
else
	-- making for all
	for _,arch in ipairs(SUPPORTED_ARCH) do
		pack(arch,arguments["profile"])
	end
end

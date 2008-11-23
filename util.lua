require "tools.config"

-- Local scope
local string = require "tools.split"
local platforms = require "tools.platforms"
local myplat = platforms[TEC_SYSNAME]
local default_osexecute = os.execute

module("tools.util", package.seeall)

-- Overloading the os.execute to dummy verbose
function verbose(level)
	if not level or level <= 0 then
		os.execute = default_osexecute
	elseif level == 1 then
		os.execute = function(...)
			print(" [verbose]: ",...)
			return default_osexecute(...)
		end
	end
end

-- TODO: create a assert like function to trigger some functions to clean
-- look: debug.getinfo ([thread,] function [, what])

-- Temporary table to register all install calls for a package
local log = { --[[ { ['name'] = { files = {}, links = {} } } ]] }

-- Install method registering what is installing on file 'BASEDIR/pkg_name.files'
function install(package, orig, dest)
	assert(type(package) == "string")
	-- ensure open the log file if not already
	if not log[package] or not log[package].files then
		if not log[package] then log[package] = { } end
		log[package].files = assert(io.open(PKGDIR.."/"..package..".files", "w"),package)
	end

	-- parsing possible regular expression of orig specification and listing
	local files = myplat.exec("ls -d "..orig)
	-- foreach filename...
	local next = files:gmatch("[^\n]+")
	local line = next()
	while (line) do
		-- ... register your dest/basename to logfile
		local dir, name = line:gmatch("(.*%/+)(.+)")()
		name = name or line
		log[package].files:write(dest.."/"..name.."\n")
		-- ... and real install of files on destination
		os.execute(myplat.cmd.mkdir .. INSTALL.TOP.. "/".. dest)
		os.execute(myplat.cmd.install .." "..orig.." "..INSTALL.TOP.."/"..dest)
		line = next()
	end

end

-- Link method registering what is linking on file 'BASEDIR/pkg_name.links'
function link(package, orig, linkpath)
	assert(type(package) == "string")
	-- ensure open the log file if not already
	if not log[package] or not log[package].links then
		if not log[package] then log[package] = { } end
		log[package].links = assert(io.open(PKGDIR.."/"..package..".links", "w"),package)
	end
	log[package].links:write(linkpath.."\n")
	local dir,name = linkpath:gmatch("(.*%/+)(.+)")()
	dir = dir or "."
	os.execute("cd "..INSTALL.TOP .."; ".. myplat.cmd.mkdir .. dir)
	-- ... and real link to destination
	os.execute("ln -sf "..orig.." "..INSTALL.TOP.."/"..linkpath)
end

-- Downloading tarballs
function fetch_and_unpack(package,from,to)
	assert(type(package) == "string" and
	       type(from) == "string")
	-- assume default destination if nil
	if not to then
		to = PRODAPP .."/".. package
	end
-- just fetch the tarball source once
	local exists = os.execute("test -d ".. to)
	if exists ~= 0 then
		print(" [info] Downloading "..package)
		local fetch_cmd = "curl -o ".. package ..".tar.gz ".. from .." || wget ".. from
		os.execute("cd ".. PRODAPP .."; ".. fetch_cmd)
		local unpack_cmd = "gzip -c -d ".. package ..".tar.gz |tar -x"
		os.execute("cd ".. PRODAPP .."; ".. unpack_cmd)
	end
end

-- Closing install log files
function close_log()
	for _,p in ipairs(log) do
		if p then p:close() end
	end
end

-- Parsing arguments and returns a 'table[option]=value'
function parse_args(arg, usage_msg, allowempty)
	assert(type(arg)=="table","ERROR: Missing arguments! This program should be loaded from console.")
	local arguments = {}
	local patt="%-?%-?(%w+)(=?)(.*)"
	-- concatenates with the custom usage_msg
	usage_msg=[[
 Usage: ]]..arg[0]..[[ OPTIONS
 Valid OPTIONS:
]] ..usage_msg

	if not (arg[1]) and not allowempty then print(usage_msg) ; os.exit(1) end

	for i,param in ipairs(arg) do
		local opt,_,value = param:match(patt)
		if opt == "h" or opt == "help" then
			print(usage_msg)
			os.exit(1)
		end
		if opt and value then
			if arguments[opt] then
				arguments[opt] = arguments[opt].." "..value
			else
				arguments[opt] = value
			end
		end
	end

	return arguments
end

-- Serializing table to file (original: http://lua.org/pil)
function serialize_table(filename,t,name)

	local f = io.open(filename,"w")
	-- if we got a named table
	if type(name) == "string" then
		f:write(name.." = ")
	end

	local function serialize(o)
		if type(o) == "number" then
			f:write(o)
		elseif type(o) == "string" then
			f:write(string.format("%q",o))
		elseif type(o) == "table" then
			f:write("{\n")
			for k,v in pairs(o) do
				if type(k) == "number" then
					f:write(" ["..tostring(k).."]=")
				else
					f:write(" "..k.." = ")
				end
				serialize(v)
				f:write(",\n")
			end
			f:write("}\n")
		else
			f:close()
			os.remove(filename)
			error("Cannot serialize types like "..type(o))
		end
	end

	serialize(t)
	f:close()
	return true
end

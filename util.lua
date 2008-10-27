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
		os.execute("mkdir -p ".. INSTALL.TOP.. "/".. dest)
		os.execute(myplat.cmd.install.." "..orig.." "..INSTALL.TOP.."/"..dest)
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
	os.execute("cd "..INSTALL.TOP .. "; mkdir -p ".. dir)
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
		local unpack_cmd = "gzip -c -d ".. package ..".tar.gz |tar -xf -"
		os.execute("cd ".. PRODAPP .."; ".. unpack_cmd)
	end
end

-- Closing install log files
function close_log()
	for _,p in ipairs(log) do
		if p then p:close() end
	end
end

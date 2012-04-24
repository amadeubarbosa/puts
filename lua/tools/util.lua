local config = require "tools.config"

-- Local scope
local string = require "tools.split"
local platforms = require "tools.platforms"
local myplat = platforms[config.TEC_SYSNAME]
local default_osexecute = os.execute
local io = io

module("tools.util", package.seeall)

--------------------------------------------------
------------------------------- logging facilities
log = {
  -- levels configuration by default
  _levels = {
    debug = false,
    info = true,
    warning = true,
    error = true,
  },
  _tags = {
   info   ="[INFO   ] ",
   debug  ="[DEBUG  ] ",
   error  ="[ERROR  ] ",
   warning="[WARNING] ",
  },
  _handlers = {
    info = io.stdout,
    debug = io.stdout,
    warning = io.stdout,
    error = io.stderr,
  }
}
for level,_ in pairs(log._levels) do
  log[level]=function(...)
    if log._levels[level] then
      local args = {...}
      for i=1,#args do
        args[i] = tostring(args[i])
      end
      log._handlers[level]:write(log._tags[level]..table.concat(args," ").."\n")
      log._handlers[level]:flush()
    end
  end
end
--------------------------- fileysystem facilities
fs = {}
function fs.is_dir(at)
   return (at and (os.execute(myplat.cmd.test.." -d "..at) == 0))
end
function fs.is_file(at)
   return (at and (os.execute(myplat.cmd.test.." -f "..at) == 0))
end

function fs.list_dir(at)
   assert(type(at) == "string" or not at)
   if not at then
      at, count = myplat.exec(myplat.cmd.pwd):gsub("\n","")
      if count ~= 1 then
        at = nil
      end
   end

   if not fs.is_dir(at) then
      return {}
   end
   local result = {}
   local pipe = io.popen("cd "..at.." && ".. myplat.cmd.ls)
   for file in pipe:lines() do
      table.insert(result, file)
   end
   pipe:close()
   return result
end
--------------------------------------------------

function split_nameversion(nameversion)
  local name, version = nameversion:match("(.-)%-(%d+.*)$")
  if not name and not version then
    name = nameversion:match("[%w%-%_]+") -- second by pass
    return name
  end
  return name, version
end

function nameversion(spec)
  assert(spec.name)
  return spec.name:lower() .. ((spec.version and "-"..spec.version) or "")
end
-- Overloading the os.execute to dummy verbose
function verbose(level)
  if not level or level <= 0 then
    os.execute = default_osexecute
  elseif level == 1 then
    log._levels.debug = true
    os.execute = function(...)
      log.debug(...)
      return default_osexecute(...)
    end
  end
end

-- TODO: create a assert like function to trigger some functions to clean
-- look: debug.getinfo ([thread,] function [, what])

-- Temporary table to register all install calls for a package
local cache = { --[[ ['name'] = { files = {}, links = {} } ]] }

-- Install method registering what is installing on file 'config.BASEDIR/pkg_name.files'
function install(package, orig, dest)
  assert(type(package) == "string")
  -- ensure open the cache file if not already
  if not cache[package] or not cache[package].files then
    if not cache[package] then cache[package] = { } end
    cache[package].files = assert(io.open(config.PKGDIR.."/"..package..".files", "w"))
  end

  -- parsing possible regular expression of orig specification and listing
  local files = myplat.exec(myplat.cmd.ls.." -d "..orig)
  -- foreach filename...
  local next = files:gmatch("[^\n]+")
  local line = next()
  while (line) do
    -- ... register your dest/basename to cachefile
    local dir, name = line:gmatch("(.*%/+)(.+)")()
    name = name or line
    cache[package].files:write(dest.."/"..name.."\n")
    -- ... and real install of files on destination
    os.execute(myplat.cmd.mkdir .. config.INSTALL.TOP.. "/".. dest)
    os.execute(myplat.cmd.install .." "..orig.." "..config.INSTALL.TOP.."/"..dest)
    line = next()
  end

end

-- Link method registering what is linking on file 'config.BASEDIR/pkg_name.links'
function link(package, orig, linkpath)
  assert(type(package) == "string")
  -- ensure open the cache file if not already
  if not cache[package] or not cache[package].links then
    if not cache[package] then cache[package] = { } end
    cache[package].links = assert(io.open(config.PKGDIR.."/"..package..".links", "w"))
  end
  cache[package].links:write(linkpath.."\n")
  local dir,name = linkpath:gmatch("(.*%/+)(.+)")()
  dir = dir or "."
  os.execute("cd "..config.INSTALL.TOP .."; ".. myplat.cmd.mkdir .. dir)
  -- ... and real link to destination
  os.execute("ln -sf "..orig.." "..config.INSTALL.TOP.."/"..linkpath)
end

---
-- Executa um comando no sistema operacional.
--
-- @return A resposta do comando em questão.
---
function execute(cmd)
  local pipe = io.popen(cmd,"r")
  local out = pipe:read("*a")
  pipe:close()

  return out
end

------------------------------------------------------------------------------
-- LuaRocks (http://www.luarocks.org) code. Thanks LuaRocks Team!
-- ... from "luarocks/fs/unix.lua"

--- Strip the path off a path+filename.
-- @param pathname string: A path+name, such as "/a/b/c".
-- @return string: The filename without its path, such as "c".
function base_name(pathname)
   assert(type(pathname) == "string")

   local base = pathname:match(".*/([^/]*)")
   return base or pathname
end

-- URLs should be in the "protocol://path" format.
-- For local pathnames, "file" is returned as the protocol.
-- @param url string: an URL or a local pathname.
-- @return string, string: the protocol, and the absolute pathname without the protocol.
function split_url(url)
  assert(type(url) == "string")
  local protocol, pathname = url:match("^([^:]*)://(.*)")
  if not protocol then
    protocol = "file"
    pathname = url
  end
  return protocol, pathname
end

--- Unpack an archive.
-- Extract the contents of an archive, detecting its format by
-- filename extension.
-- @param path string: Pathname of directory where extract the archive.
-- @param archive string: Filename of archive.
-- @return boolean or (boolean, string): true on success, false and an error message on failure.
function unpack_archive(path,archive)
  assert(type(archive) == "string")

  local unpack_cmd
  if archive:match("%.tar%.gz$") or archive:match("%.tgz$") then
    unpack_cmd = myplat.cmd.gunzip ..archive.."|".. myplat.cmd.tar .."-xf -"
  elseif archive:match("%.tar%.bz2$") then
    unpack_cmd = myplat.cmd.bunzip2 ..archive.."|".. myplat.cmd.tar .."-xf -"
  elseif archive:match("%.zip$") then
    unpack_cmd = myplat.cmd.unzip ..archive
  else
    local ext = archive:match(".*(%..*)")
    return false, "Unrecognized filename extension "..(ext or "")
  end
  local ok = os.execute("cd "..path.." && "..unpack_cmd)
  if ok ~= 0 then
    return false, "Failed extracting "..archive
  end
  return true
end
------------------------------------------------------------------------------
-- Downloading
function download(pkgname, from, targetdir)
  assert(type(pkgname) == "string" and type(from) == "string")
  local proto, url = split_url(from)

  local handler
  if proto == "http" or proto == "https" or proto == "ftp" then
    -- location where put the downloaded file
    -- ATTENTION: ignoring the targetdir to use a common directory to put the
    -- downloaded files
    targetdir = targetdir or config.DOWNLOADDIR
    assert(os.execute(myplat.cmd.mkdir .. targetdir) == 0, "ERROR: Cannot create the directory '".. targetdir .."' to download the package into it.")
    if exists_pkgfile(targetdir, pkgname) then
      filepath = targetdir.."/"..base_name(url)
      log.info("Skipping the download of the "..pkgname.." because is already downloaded. If you need update it so you must to remove the file '"..filepath.."'")
      return true, filepath
    end
    handler = require "tools.fetch.http"
  elseif proto:match("^svn") then
    -- location as the checkout directory
    targetdir = targetdir or  config.PRODAPP.."/".. pkgname
    handler = require "tools.fetch.svn"
    -- https or http isn't a valid tunnel in subversion syntax
    -- we use the "svn+https" to represent "svn" protocol using an "https" url
    local tunnel = proto:match("^svn%+(.*)")
    if tunnel == "https" or tunnel == "http" then
      proto = tunnel
      from = proto .."://".. url
    end
  else
    -- trying load from disk a handler
    ok, handler = pcall(require, "tools.fetch."..proto)
    if not ok then
      error("ERROR: Unknown protocol '"..proto.."'. The URL was '"..from.."'.")
    end
  end
  log.debug("Downloading ",pkgname,"using the protocol",proto)
  return handler.run(targetdir,from)
end

-- Testing the archive existance
function exists_pkgfile(path,pkgname)
  assert(type(pkgname) == "string")
  local known_exts = ".tar.gz .tgz .tar.bz2 .zip"
  local ext
  while(type(known_exts) == "string") do
    ext,known_exts = known_exts:match("(%S+)(.*)")
    if ext and (os.execute("test -f "..path.."/"..pkgname..ext) == 0) then
      return true
    end
  end
  return false
end

-- Downloading tarballs
function fetch_and_unpack(package,from,targetdir)
  assert(type(package) == "string" and
         type(from) == "string")
  local ok, filepath = download(package,from,targetdir)
  if not targetdir then
    targetdir = config.PRODAPP .."/".. package
  end
  assert(ok, "ERROR: Unable to download the package. You must download this package manually from '"..from.."' and extract it in the '"..targetdir.."' directory.")
  -- it only extracts the source once
  local exists = os.execute("test -d ".. targetdir)
  if exists ~= 0 then
    -- it will extract inside the config.PRODAPP directory using the filename
    assert(unpack_archive(config.PRODAPP,filepath), "ERROR: Unable to extract the package '".. filepath.."' in the directory '".. config.PRODAPP .."'.")
  end
  return true
end

-- Closing install cache files
function close_cache()
  for p, t in pairs(cache) do
    for _, file_cache in pairs(t) do
      file_cache:close()
    end
  end
end

-- this pattern only matches identifiers that could be used as a Lua variable identifier
local patt="%-?%-?([%w%_]+)(=?)(.*)"

-- Parsing arguments and returns a 'table[option]=value'
function parse_args(arg, usage_msg, allowempty)
  assert(type(arg)=="table","ERROR: Missing arguments! This program should be loaded from console.")
  assert(usage_msg)
  local arguments = {}
  -- concatenates with the custom usage_msg
  usage_msg=[[
 Usage: ]]..tostring(arg[0])..[[ OPTIONS
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
        if #arguments[opt] == 0 then
          arguments[opt] = value
        else
          arguments[opt] = arguments[opt].." "..value
        end
      else
        arguments[opt] = value
      end
    end
  end

  return arguments
end

-- Serializing table to file (original: http://lua.org/pil)
function serialize_table(filename,t,name)
  local f = assert(io.open(filename,"w"))
  -- if we got a named table
  if type(name) == "string" then
    f:write(name.." = ")
  end

  local function serialize(o,firsttime)
    if type(o) == "number" then
      f:write(o)
    elseif type(o) == "boolean" then
      f:write(tostring(o))
    elseif type(o) == "string" then
      f:write(string.format("%q",o))
    elseif type(o) == "table" then
      if firsttime then
        for k,v in pairs(o) do
          assert(type(k)=="string")
          f:write(" "..k.." = ")
          serialize(v)
        end
      else
        f:write("{\n")
        for k,v in pairs(o) do
          if type(k) == "number" then
            f:write(" ["..tostring(k).."] = ")
          elseif k:match("%p") then
            f:write(" [\""..tostring(k).."\"] = ")
          else
            f:write(" "..k.." = ")
          end
          serialize(v)
          f:write(",\n")
        end
        f:write("}\n")
      end
    else
      f:close()
      os.remove(filename)
      error("Cannot serialize types like "..type(o))
    end
  end

  if name then
    serialize(t)
  else
    serialize(t,true)
  end
  f:close()
  return true
end

function deep_copy(table_orig, table_new)
  table_new = table_new or {}
  if type(table_orig) ~= "table" then
    return table_orig
  end
  
  local function copy(index, value)
    if type(value) == "table" then
      table_new[index] = deep_copy(table_orig[index])
    else
      assert(type(value) ~= "userdata", "userdata types not supported in util.deep_copy function")
      table_new[index] = value
    end
  end
  -- key/value pairs
  for key,value in pairs(table_orig) do
    copy(key,value)
  end
  -- numeric values
  for index,value in ipairs(table_orig) do
    copy(index,value)
  end
  
  return table_new
end

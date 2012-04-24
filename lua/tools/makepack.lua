#!/usr/bin/env lua5.1
package.path = "?.lua;../?.lua;" .. package.path

-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local log  = util.log

-- Local scope
local string = require "tools.split"
local platforms = require "tools.platforms"
local myplat = platforms[config.TEC_SYSNAME]

module("tools.makepack", package.seeall)

local RELEASEINFO = nil

--- Retrieves the release information
function getrelease()
  -- Identifying the release by 2 ways:
  -- 1. if the svn command is available
  local url
  local svnCommandExists = os.execute("which svn >/dev/null") == 0
  local svnDirectoryExists = os.execute("test -d "..config.SVNDIR) == 0
  if svnCommandExists then
    if not svnDirectoryExists then
      return false, string.format("Configuration problem, directory %s doesn't exist. Check the PUTS configuration file or use the argument --svndir.",config.SVNDIR)
    end 
    url = myplat.exec("cd "..config.SVNDIR.." && env LANG=C svn info |grep URL")
    -- Removing 'URL:' and '\n'.
    url = url:match("URL:%s*(.+)([%p%c%s]+)$")
  end
  -- 2. or if the config already provides it
  url = url or config.SVNURL
  log.debug("Generating release information: Parsing the URL",url)

  local _,tag = url:match("(.+)/(.+)$")
  if tag and tag == "trunk" and svnCommandExists then
    local rev = myplat.exec("cd "..config.SVNDIR.." && env LANG=C svn info|grep Rev:")
    rev = rev:match(".*Rev:%s*(%w+).*$")
    if rev then
      tag = "OB_HEAD_r"..rev
      log.debug("Generating release information: Revision mark",rev)
    end
  end
  -- when ...openbus/trunk ; url = ...openbus and tag = OB_r27387 ??
  -- when ...openbus/branches/OB_v1_10_2008_12_12 ; url = ...openbus/branches and tag = OB_v1_10..

  if not tag then
    return false, "Couldn't identify the release information automatically (URL: "..url..")."
  else
    log.info("Using the following release information to create packages:",tag)
    return tag
  end
end

--- Packs in a tarball named by profile
function pack(arch,profile)
  local tarball_files = ""
  local metadata_files = ""
  -- Adds file contents to a big string
  local function add(f)
    if f then
      local str = f:read("*a"):gsub("\n"," "):gsub("${TEC_UNAME}",arch)
      tarball_files = tarball_files .. str
      f:close()
    end
  end

  local function addmetadata(filename)
    local name = filename:match("(.*).template")
    if name ~= nil then
      local i = 1
      local filename = name ..".template.".. i
      while io.open(filename,"r") do
        metadata_files = metadata_files .." ".. filename
        i = i + 1
        filename = name ..".template."..i
      end
    elseif io.open(filename,"r") then
      metadata_files = metadata_files .." ".. filename
    end
  end

  local _,name = profile:match("(.*)/(.*)") --extracts name "dir/name.profile"
  name = name or profile                    --could nil only if "name.profile"
  name = name:gsub(".profile","")           --deletes the suffix ".profile"

  print "----------------------------------------------------------------------"
  log.info("Generating the tarball for arch:".. arch .." profile:".. name)
  local file = assert(io.open(profile,"r") or
      io.open(name..".profile","r") or
      io.open(config.DEPLOYDIR .."/profiles/".. name,"r") or
      io.open(config.DEPLOYDIR .."/profiles/".. name ..".profile","r"),"ERROR: Couldn't find the file describing the profile "..name)

  -- Overwriting some global variables with arch values
  -- Using 'tools.config.changePlatform' global function
  local pkgdir = config.changePlatform(arch)

  -- Function to parse profile description and find metadata files to be used
  local already_included = {} --avoid duplicates
  local function include_on_package(profile_file, pkgdir, categories_cache)
    assert(type(profile_file) == "userdata")
    local iterator = profile_file:lines()
    repeat
      local line = iterator()
      if line then
        local m = line:gmatch("%S+")
        local name = m() --first result is always the name-version of the package
        local categories = categories_cache or {}
        repeat
          local cat = m()
          if cat then
            categories[cat] = true
          end
        until (cat == nil)
      
        if name and not already_included[name] then
          if categories["+conf"] then
            addmetadata(pkgdir.."/"..name..".template")   --gerado pelo conf_template
            addmetadata(pkgdir.."/"..name..".conf.files") --gerado pelo conf_files
            add(io.open(pkgdir.."/"..name..".conf.files"))
          end
          if categories["+dev"] then
            addmetadata(pkgdir.."/"..name..".dev.files")  --gerado pelo conf_files          
            add(io.open(pkgdir.."/"..name..".dev.files","r"))
          end
          local path = pkgdir.."/"..name..".dependencies"
          if util.fs.is_file(path) then
            addmetadata(path)
            if categories["+dependencies"] then
                -- recursively
                local deps_file = assert(io.open(path,"r"))
                include_on_package(deps_file, pkgdir, categories)
            end
          end
          addmetadata(pkgdir.."/"..name..".files")      --gerado pelo install_files
          add(io.open(pkgdir.."/"..name..".files","r"))
          addmetadata(pkgdir.."/"..name..".links")      --gerado pelo simbolic_links
          add(io.open(pkgdir.."/"..name..".links","r"))
          already_included[name] = true
        end
      end
    until (line == nil)
    profile_file:close()
  end

  include_on_package(file, pkgdir)
  already_included = nil

  -- Creates a metadata.tar.gz and include it in tarball_files
  -- Tip: the installation actually is inside of config.INSTALL.TOP !
  local release
  if RELEASEINFO then
    release = RELEASEINFO
  else
    release, msgInvalidRelease = getrelease()
    if not release then
      log.error(msgInvalidRelease)
      return false
    end
  end
  
  local metadata_dirname = "metadata-"..release.."-"..name
  assert(os.execute(myplat.cmd.mkdir .. config.TMPDIR .."/"..metadata_dirname) == 0)
  assert(os.execute(myplat.cmd.install .. metadata_files .." "..config.TMPDIR.."/"..metadata_dirname) == 0)
  assert(os.execute("cd ".. config.TMPDIR .." && ".. myplat.cmd.tar .."-cf - ".. metadata_dirname .." |gzip > ".. metadata_dirname ..".tar.gz") == 0)
  assert(os.execute("mv ".. config.TMPDIR .."/".. metadata_dirname ..".tar.gz ".. config.INSTALL.TOP) == 0)
  assert(os.execute(myplat.cmd.rm .. config.TMPDIR) == 0)
  tarball_files = tarball_files .." ".. metadata_dirname..".tar.gz "

  -- Call the 'tar' command
  local excludefile = os.tmpname()
  local tar_cmd = "cd ".. config.INSTALL.TOP .." && "
  tar_cmd = tar_cmd .. "find . -name .svn -type d |sed \"s#^./##\" >"..excludefile.." && ".. myplat.cmd.tar .."cfX - "..excludefile.." "
  tar_cmd = tar_cmd .. tarball_files
  local tarball = config.DOWNLOADDIR.."/".. config.PKGPREFIX .. release .."-"..name.."-".. arch .. ".tar.gz"
  tar_cmd = tar_cmd .. "|gzip > "..tarball
  assert(os.execute(tar_cmd) == 0, "Cannot execute the command \n"..tar_cmd..
                    "\n, ensure that 'tar' command has --exclude option!")

  -- Cleans the temporary excludefile
  os.remove(excludefile)
  log.info("Package created! Check the file: "..tarball)
  print "----------------------------------------------------------------------"
  return true
end

--------------------------------------------------------------------------------
-- Main code -------------------------------------------------------------------
--------------------------------------------------------------------------------

function run()
  -- Parsing arguments
  local arguments = util.parse_args(arg,[[
    --help                   : show this help
    --verbose                : turn ON the VERBOSE mode (show the system commands)
    --profile=filename       : use the 'filename' as input for profile with the
                               list of packages to packaging
    --arch=tecmake_arch      : specifies the arch based on tecmake way. Use 'all'
                               to pack all supported architectures
    --svndir=/my/directory   : path to directory where are the source codes
                               (generates automatically the release information)
    --release=STRING_RELEASE : string to be used as release information
                               (bypass manually the release information)

   NOTES:
    The prefix '--' is optional in all options.
    So '--help' or '-help' or yet 'help' all are the same option.]])

  if arguments["v"] or arguments["verbose"] then
    arguments["v"] = true
    arguments["verbose"] = true
    util.verbose(1)
  end
  if arguments["svndir"] then
    config.SVNDIR = arguments["svndir"]
  end
  if arguments["release"] then
    log.warning("You're overloading the 'release' information that should be extracted from the source directory!")
    RELEASEINFO = arguments["release"]
  end

  assert(arguments["profile"],"Missing argument --profile!")
  assert(arguments["arch"] or config.TEC_UNAME,"Missing argument --arch and not found TEC_UNAME env!")
  arguments["arch"] = arguments["arch"] or config.TEC_UNAME

  if arguments["arch"] ~= "all" then
    return pack(arguments["arch"],arguments["profile"])
  else
    -- making for all
    log.info("Creating multiples packages ...")
    for _,arch in ipairs(config.SUPPORTED_ARCH) do
      local ok = pack(arch,arguments["profile"])
      if not ok then
        return false
      end
    end
  end

  return true
end

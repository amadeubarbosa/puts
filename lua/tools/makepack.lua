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

--- Retrieves the release information
function getrelease()
  -- Identifying the release by 2 ways:
  -- 1. if the svn command is available
  local url
  local svnCommandExists = os.execute("which svn >/dev/null") == 0
  local svnDirectoryExists = os.execute("test -d "..config.SVNDIR) == 0
  if svnCommandExists then
    if not svnDirectoryExists then
      return false, string.format("Configuration problem, directory %s doesn't exist. Check the PUTS configuration file or use the option --svndir.",config.SVNDIR)
    end 
    url = myplat.exec("cd "..config.SVNDIR.." && env LANG=C svn info |grep URL")
    -- Removing 'URL:' and '\n'.
    url = url:match("URL:%s*(.+)([%p%c%s]+)$")
  end
  -- 2. or if the config already provides it
  url = url or config.SVNURL
  log.debug("Generating release information: URL",url)

  local _,tag = url:match("(.+)/(.+)$")
  if tag and tag == "trunk" and svnCommandExists then
    local rev = myplat.exec("cd "..config.SVNDIR.." && env LANG=C svn info|grep Rev:")
    rev = rev:match(".*Rev:%s*(%w+).*$")
    if rev then
      tag = "OB_HEAD_r"..rev
      log.debug("Generating release information: Revision",rev)
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
function pack(arch,profile,release,project)
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

  -- Identifying the release information
  if not release then
    release, errmsg = getrelease()
    if not release then
      log.error(errmsg)
      return false
    end
  end

  -- Loading profile
  local _,name = profile:match("(.*)/(.*)") --extracts name "dir/name.profile"
  name = name or profile                    --could nil only if "name.profile"
  name = name:gsub(".profile","")           --deletes the suffix ".profile"

  local filename_guesses = {
    profile,
    name..".profile",
    config.DEPLOYDIR .."/profiles/".. name,
    config.DEPLOYDIR .."/profiles/".. name ..".profile",
  }
  local file, errmsg = nil
  for _, try in ipairs(filename_guesses) do
    file, errmsg = io.open(try,"r")
    if file then
      break
    else
      filename_guesses[try] = errmsg
    end
  end

  -- In case of errors, we explain better what happens
  if not file then
    log.error("Couldn't open the profile",name,". Errors caught:")
    for i, filename_tried in ipairs(filename_guesses) do
      if type(filename_tried) == "string" then
        log.error("\t",filename_guesses[filename_tried])
      end
    end
    return false
  end

  log.info("Generating the tarball for architecture",arch,"using profile",name)
  -- Overwriting some global variables with arch values
  -- Using 'tools.config.changePlatform' global function
  local pkgdir
  if arch == "all" then
    pkgdir = config.changePlatform(config.TEC_UNAME)
  else
    pkgdir = config.changePlatform(arch)
  end

  if not util.fs.is_dir(pkgdir) then
    log.warning("Your system was recognized as '"..arch.."'. If you wish change this use --arch option.")
    log.error(pkgdir,"is not a directory, metadata about installed packages cannot be found.")
    return false
  end
  -- Function to parse profile description and find metadata files to be used
  local already_included = {} --avoid duplicates
  local function include_on_package(profile_file, pkgdir, categories_cache)
    assert(type(profile_file) == "userdata")
    local missing = {}
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
      
        local all_metadata_supported = {
          pkgdir.."/"..name..".files",
          pkgdir.."/"..name..".dev.files",
          pkgdir.."/"..name..".conf.files",
          pkgdir.."/"..name..".links",
          pkgdir.."/"..name..".template",
          pkgdir.."/"..name..".dependencies",
        }
        local total_missing = 0
        for i, f in ipairs(all_metadata_supported) do
          if not util.fs.is_file(f) then
            total_missing = total_missing + 1
          end
        end
        if total_missing == #all_metadata_supported then
          table.insert(missing, name)
          name = nil -- forced skip the loading of metadata associated
        end

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
    if #missing > 0 then
      return false, missing
    else
      return true
    end
  end

  -- Processing all metadata files
  local ok, missed = include_on_package(file, pkgdir)
  if not ok then
    log.error("Missing metadata about the following packages:")
    for i, miss in ipairs(missed) do
      log.error("\t",miss)
    end
    return false
  end
  already_included = nil

  -- Creating a .tar.gz with all metadata files 
  local metadata_dirname = "metadata-"..release.."-"..name
  assert(os.execute(myplat.cmd.mkdir .. config.TMPDIR .."/"..metadata_dirname) == 0)
  assert(os.execute(myplat.cmd.install .. metadata_files .." "..config.TMPDIR.."/"..metadata_dirname) == 0)
  assert(os.execute("cd ".. config.TMPDIR .." && ".. myplat.cmd.tar .."-cf - ".. metadata_dirname .." |gzip > ".. metadata_dirname ..".tar.gz") == 0)
  assert(os.execute("mv ".. config.TMPDIR .."/".. metadata_dirname ..".tar.gz ".. config.INSTALL.TOP) == 0)
  assert(os.execute(myplat.cmd.rm .. config.TMPDIR) == 0)
  tarball_files = tarball_files .." ".. metadata_dirname..".tar.gz "

  -- Creating a .tar.gz with all regular files
  local excludefile = os.tmpname()
  local pkgprefix = (project and project.."-") or config.PKGPREFIX
  local tar_cmd = "cd ".. config.INSTALL.TOP .." && "
  tar_cmd = tar_cmd .. "find . -name .svn -type d |sed \"s#^./##\" >"..excludefile.." && ".. myplat.cmd.tar .."cfX - "..excludefile.." "
  tar_cmd = tar_cmd .. tarball_files
  local tarball = config.DOWNLOADDIR.."/".. pkgprefix .. release .."-"..name.."-".. arch .. ".tar.gz"
  tar_cmd = tar_cmd .. "|gzip > "..tarball
  assert(os.execute(tar_cmd) == 0, "Cannot execute the command \n"..tar_cmd..
                    "\n, ensure that 'tar' command supports --exclude option!")

  -- Cleans the temporary excludefile
  os.remove(excludefile)
  log.info("Package",tarball,"created.")
  return true
end

--------------------------------------------------------------------------------
-- Main code -------------------------------------------------------------------
--------------------------------------------------------------------------------

function run()
  local help_msg = [[
    --help                   : show this help
    --verbose                : turn ON the VERBOSE mode (show the system commands)
    --profile=filename       : use the 'filename' as input for profile with the
                               list of packages to packaging
    --arch=STRING_ARCH       : specifies the Tecmake-based architecture identification 
                               or 'all' for platform-independent packages
    --svndir=/my/directory   : path to directory where are the source codes
                               (generates automatically the release information)
    --release=STRING_RELEASE : string to be used as release information
                               (bypass manually the release information)
    --project=STRING_PROJECT : string to be used as prefix in package names
                               (default: openbus)

   NOTES:
    The prefix '--' is optional in all options.
    So '--help' or '-help' or yet 'help' all are the same option.]]
  -- Parsing arguments
  local arguments = util.parse_args(arg, help_msg)

  if arguments.v or arguments.verbose then
    arguments.v = true
    arguments.verbose = true
    util.verbose(1)
  end

  if arguments.svndir then
    config.SVNDIR = arguments.svndir
  end

  if arguments.release then
    log.warning("You're overloading release information with '"..arguments.release.."'.")
  end

  if not arguments.profile then
    log.error("No profile informed, missing option --profile!")
    table.insert(arg,"help")
    util.parse_args(arg, help_msg)
    return false
  end

  arguments.arch = arguments.arch or config.TEC_UNAME
  if not arguments.arch then
    log.error("Your system wasn't recognized, missing option --arch!")
    table.insert(arg,"help")
    util.parse_args(arg, help_msg)
    return false
  end

  if arguments.project then
    log.info("Package name will be something like:",arguments.project.."-"..(arguments.release or "<release>").."-"..arguments.profile.."-"..arguments.arch..".tar.gz")
  end

  return pack(arguments.arch, arguments.profile, arguments.release, arguments.project)
end

if not package.loaded["tools.console"] then
  os.exit((run() and 0) or 1)
end

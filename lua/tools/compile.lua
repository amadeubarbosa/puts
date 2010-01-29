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

module("tools.compile", package.seeall)

-- Parses package description and delegates to tools.build.<method>.run
function parseDescriptions(desc, arguments)
  for _, t in ipairs(desc) do
    print "----------------------------------------------------------------------"
    -- hack when no build is provided, to _always_ copy install_files , dev_files
    if not t.build then
      t.build = { type = "copy" }
    end

    -- Back-compatibility to support the old Openbus (=< 1.4.2) package descriptions
    if arguments["compat"] and t.source then
      t.url = t.source
    end
    -- fetching and unpacking
    if t.url and arguments["update"] then
      util.fetch_and_unpack(t.name, t.url, t.directory)
    end
  
    assert(t.build.type, "ERROR: build.type is missing for package: "..t.name)
    -- loading specific build methods
    ok, build_type = pcall(require, "tools.build." .. t.build.type)
    assert(ok and type(build_type) == "table","ERROR: failed initializing "..
                        "build back-end for build type: '".. t.build.type ..
                        "' for package: ".. t.name)

    -- starting specific build methods
    build_type.run(t,arguments,t.directory)

    print "[ INFO ] Done!"
    print "----------------------------------------------------------------------"
  end
end

--------------------------------------------------------------------------------
-- Main code -------------------------------------------------------------------
--------------------------------------------------------------------------------

function run()
  -- Parsing arguments
  local arguments = util.parse_args(arg,[[
    --help                   : show this help
    --verbose                : turn ON the VERBOSE mode (show the system commands)
    --basesoft=filename      : use the 'filename' as input for basic
                               softwares with autotools semantic (i.e: openssl)
    --packages=filename      : use the 'filename' as input for packages
                               with tecmake semantic (i.e: lua5.1, openbus-core)
    --rebuild                : changes the default rule to rebuild the packages if
                               they're already compiled
    --force                  : forces the compile and install (i.e: you want
                               re-generate some library even it's installed
                               already, very common for debug and devel purposes)
    --list                   : list all package names from description files. When
                               '--select' is used, it'll help you to validate your choose.
    --select="pkg1 pkg2 ..." : choose which packages to compile and install
    --profile="file1 file2..." : use a list of 'filenames' representing the profiles
                                   which have a list of packages inside (it will append 
                                   to the select list)
    --exclude="pkg1 pkg2 ..."  : list of package to exclude of the compile process
    --update           : updates the source codes from the repositories

   BACK-COMPATIBILITY OPTIONS:
    --compat                 : changes the parsing of the package descriptions to
                                     support the old format used until the Openbus 1.4.2

   NOTES:
    The prefix '--' is optional in all options.
    So '--help' or '-help' or yet 'help' all are the same option.]],true)

  if arguments.select then
    local value = arguments.select
    -- selecting packages to build with multiple '--select' support
    arguments.select = {value:split("[^%s]+")}
  end
  if arguments.exclude then
    local value = arguments.exclude
    -- selecting packages to build with multiple '--exclude' support
    arguments.exclude = {value:split("[^%s]+")}
  end
  if arguments.profile then
    local value = arguments.profile
    -- selecting packages to build with multiple '--profile' support
    arguments.profile = {value:split("[^%s]+")}
  end

  if arguments["v"] then
    arguments["verbose"] = true
  end

  print("[ INFO ] We are going to install full openbus dependencies on \
  ".. INSTALL.TOP .." and temporary install directories \
  (for autotools based packages) on ".. TMPDIR .." .\n")

  -- Loading basesoft and package descriptions tables
  local f, err = loadfile(arguments["basesoft"] or DEPLOYDIR .."/basesoft.desc")
  if not f then
    io.stdout:write("[ ERROR ] "); io.stdout:flush()
    error("The file '".. (arguments["basesoft"] or DEPLOYDIR.."/basesoft.desc") .. "' cannot be opened!\nTry use the --basesoft option in command line with a valid filename.\n")
  end
  f()

  local f, err = loadfile(arguments["packages"] or DEPLOYDIR .."/packages.desc")
  if not f then
    io.stdout:write("[ ERROR ] "); io.stdout:flush()
    error("The file '".. (arguments["packages"] or DEPLOYDIR.."/packages.desc") .. "' cannot be opened!\nTry use the --packages option in command line with a valid filename.\n")
  end
  f()

  -- Filtering the descriptions tables with '--select' arguments
  -- preparing the tables to provide t[pkg_name] fields
  local function rehashByName(mytable)
    -- REMEMBER: loop.ordered.set is better but insert 'loop' module dependency
    for i,t in ipairs(mytable) do
      mytable[t.name] = t
    end
  end

  rehashByName(basesoft)
  rehashByName(packages)

  -- Including package names (using select semantics) from a profile
  if arguments["profile"] then
    for _,profile in ipairs(arguments["profile"]) do 
    local _,name = profile:match("(.*)/(.*)") --extracts name "dir/name.profile"
    name = name or profile                    --could nil only if "name.profile"
    name = name:gsub(".profile","")           --deletes the suffix ".profile"
      local file = assert(io.open(profile,"r") or 
          io.open(name..".profile","r") or 
          io.open(DEPLOYDIR .."/profiles/".. name,"r") or 
          io.open(DEPLOYDIR .."/profiles/".. name ..".profile","r"))
      
      -- Listing packages from profile description
      local l = file:lines()
      repeat
        packagename = l()
        if packagename then
          -- Removing the suffix -dev or -conf to recognize the correct package
          -- name (that will produce the sub-packages with suffixes -dev and -conf)
          packagename = packagename:match("(.*)-dev") or 
                        packagename:match("(.*)-conf") or 
                        packagename
          if not arguments.select then
             arguments.select = {}
          end
          -- Using the package to fill the arguments.select vector
          table.insert(arguments.select,packagename)
        end
      until (packagename == nil)
    end
  end

  -- real filtering
  local newbasesoft = {}
  local newpackages = {}
  if arguments["select"] then
    for _,pkg in ipairs(arguments["select"]) do
      -- cloning the references in new tables
      if basesoft[pkg] and not newbasesoft[pkg] then
        table.insert(newbasesoft,basesoft[pkg])
        newbasesoft[pkg] = basesoft[pkg]
      end
      if packages[pkg] and not newpackages[pkg] then
        table.insert(newpackages,packages[pkg])
        newpackages[pkg] = packages[pkg]
      end
    end
    -- replace the main references to cloned tables
    --it only updates the references when some package was selected
    --if #newbasesoft > 0 then basesoft = newbasesoft end
    --if #newpackages > 0 then packages = newpackages end

    -- always updates the references
    basesoft = newbasesoft
    packages = newpackages
  end

  -- Filtering the packages and basesoft list to remove some packages from the
  -- selection
  if arguments["exclude"] then
    local excludes = arguments.exclude
    for i,pkgname in ipairs(excludes) do
      excludes[pkgname] = i
    end
    local newbasesoft = {}
    local newpackages = {}
    for i,pkgdesc in ipairs(basesoft) do
     if not arguments.exclude[pkgdesc.name] then
       table.insert(newbasesoft,pkgdesc)
     else
       print("[ INFO ] Excluding the package named: ", pkgdesc.name)
     end
    end
    for i,pkgdesc in ipairs(packages) do
     if not arguments.exclude[pkgdesc.name] then
       table.insert(newpackages,pkgdesc)
     else
       print("[ INFO ] Excluding the package named: ", pkgdesc.name)
     end
    end
    basesoft = newbasesoft
    packages = newpackages
  end

  -- Back-compatibility option to understand the old package description format
  -- See the implementation of the parseDescriptions() function also.
  if arguments["compat"] then
    print("[ INFO ] Assuming the package description format used by the "..
          "Openbus 1.4.2 or earlier.")
    print("[ INFO ] Inserting a built-in source package to download (and "..
          "update) the sources of the Openbus branch ("..SVNURL..") ("..SVNDIR..").")
    -- Problem: Old versions of the 'compile' assistant downloaded the
    -- openbus-source as default.
    -- Solution: We have to insert a new description by default.
    table.insert(basesoft,{
      name = "openbus-source",
      url = SVNURL,
      directory = SVNDIR,
    })
    -- Problem: By default any package is placed under PRODAPP/pkg.name but
    -- some packages don't use tecmake backend (or other compile backend,
    -- what could fill the build_src third argument on build.copy) so they
    -- won't be placed correctly for the build.copy backend executes on.
    -- Solution: We have to insert the 'directory' field in that descriptions.
    if packages["licenses"] then
      packages["licenses"].directory = SVNDIR
    end
  end

  -- Listing packages when '--list' arguments
  if arguments["list"] then
    print "[ INFO ] Available basesoft to compile and install:"
    for _, t in ipairs(basesoft) do
      print("\t"..t.name)
    end
    print "\n[ INFO ] Available packages to compile and install:"
    for _, t in ipairs(packages) do
      print("\t"..t.name)
    end
    os.exit(0)
  end

  -- Setting verbose level if requested
  if arguments["verbose"] then
    util.verbose(1)
  end

  -- Creating the build environment to create .tar.gz (later) from it
  os.execute(myplat.cmd.mkdir .. INSTALL.TOP)
  os.execute(myplat.cmd.mkdir .. INSTALL.LIB)
  os.execute(myplat.cmd.mkdir .. INSTALL.BIN)
  os.execute(myplat.cmd.mkdir .. INSTALL.INC)
  os.execute(myplat.cmd.mkdir .. TMPDIR)
  os.execute(myplat.cmd.mkdir .. PRODAPP)
  os.execute(myplat.cmd.mkdir .. DOWNLOADDIR)
  os.execute(myplat.cmd.mkdir .. PKGDIR)

  -- Cleaning the temp dir to execute install rules of autotools softwares
  os.execute(myplat.cmd.rm .. TMPDIR .."/*")

  -- Parsing descriptions and proceed to compile & install procedures
  parseDescriptions(basesoft, arguments)
  parseDescriptions(packages, arguments)

  -- Cleaning environment
  os.execute(myplat.cmd.rm .. TMPDIR)
  --~ I shouldn't need this!!
  --~ os.execute("cd ".. INSTALL.TOP.. "; unlink lib/lib")
  --~ os.execute("cd ".. INSTALL.TOP.. "; unlink include/include")
  --~ os.execute("cd ".. INSTALL.TOP.. "; unlink core/services/services")

  -- Closing install log files
  util.close_log()

end

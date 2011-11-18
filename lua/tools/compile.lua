#!/usr/bin/env lua5.1
package.path = "?.lua;../?.lua;" .. package.path

-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"

-- Local scope
local string = require "tools.split"
local platforms = require "tools.platforms"
local myplat = platforms[TEC_SYSNAME]

module("tools.compile", package.seeall)

--------------------------------------------------------------------------------
-- Utility functions -----------------------------------------------------------
--------------------------------------------------------------------------------

-- Iterates a numeric ordered table and create a new index with field 'name'
local function indexByName(table)
  -- REMEMBER: 
  -- loop.ordered.set is better but it insert 'loop' module dependency
  for i,t in ipairs(table) do
    table[t.name] = t
  end
  return table
end
-- Merges two tables into the first one
local function mergeTables (t1, t2)
  assert(t1 and t2,"both parameters must be tables")
  for i,elem in ipairs(t2) do
    table.insert(t1,elem)
  end
  return t1
end
-- Selects all .desc from a directory
local function loadDescriptorsFromDir(dir, list)
  assert(type(dir) == "string" and type(list) == "table","directory must be a string and list must be a table")
  local files = myplat.exec(myplat.cmd.ls.." "..dir.."/*.desc "..myplat.pipe_stderr)
  -- foreach filename...
  local nextFile = files:gmatch("[^\n]+")
  local filename = nextFile()
  while (filename) do
    print("[ INFO ] Descriptor '".. filename .."' found automatically")
    table.insert(list,filename)
    filename = nextFile()
  end
  return list
end

--------------------------------------------------------------------------------
-- Checkpoint code -------------------------------------------------------------
--------------------------------------------------------------------------------

-- Checkpoint allows us to 'restore' and 'save' recover files.
-- Recover files register when the compiler assistant fails on building a package.
-- The compiler will continue the package building from the last package compiled successfully.
local checkpoint = { filename = BASEDIR.."/compiler.recover", packages = {} }

function checkpoint:clean()
  os.remove(self.filename)
  return true
end

function checkpoint:loadRecoverFile()
  local alreadyCompiled = {}
  local loader = loadfile(self.filename,"r")
  if not loader then
    -- there is no checkpoint to recover from
    return false
  end
  
  setfenv(loader, alreadyCompiled)
  loader()
  self.packages = alreadyCompiled.packages

  return true
end

function checkpoint:getCorrectlyCompiled(packageRequestedList)
  if not self:loadRecoverFile() then
    return packageRequestedList
  end
  
  local compiled = {}
  for i, pkg in ipairs(packageRequestedList) do
    if self.packages[pkg] then
      table.insert(compiled, pkg)
      compiled[pkg] = true
    end
  end
  
  return compiled
end

function checkpoint:saveRecoverFile(descriptors, lastPkgBeingCompiled)
  assert(type(descriptors) == "table")
  assert(type(lastPkgBeingCompiled) == "number")
  
  local info = {}
  -- persists the package names about the current checkpoint (if it exists)
  -- plus the packages built in this current execution
  for i=1,lastPkgBeingCompiled-1 do
    -- saving pkginfo as 'mypackage = true' in recover file
    self.packages[ descriptors[i].name ] = true
  end
  
  assert(util.serialize_table(self.filename, self.packages, "packages"))
  -- registering when this file was created
  local recoverFile = io.open(self.filename,"a+")
  recoverFile:write("-- date: "..os.date().."\n")
  recoverFile:write("-- arguments: ")
  for i,param in ipairs(arg) do
    recoverFile:write(param.." ")
  end
  recoverFile:write("\n")
  recoverFile:close()
  return true
end

--------------------------------------------------------------------------------
-- Back-compatibility code -----------------------------------------------------
--------------------------------------------------------------------------------

-- Functions related to back-compatibility mode
local compat = {
    loadDescriptors = function (arguments)
      -- Earlier we used DEPLOYDIR = SVNDIR.."/tools"
      -- Hack needed to convert from SVNDIR.."/specs" to old name
      local oldDirectory = DEPLOYDIR:gsub("specs$","tools")
      local filepath = arguments["basesoft"] or oldDirectory.."/basesoft.desc"

      -- Loading basesoft description table
      local f, err = loadfile(filepath)
      if not f then
        io.stdout:write("[ ERROR ] "); io.stdout:flush()
        error("The file '".. filepath .. "' cannot be opened or hasn't a valid syntax!")
      end
      f()
      assert(type(basesoft)=="table","invalid 'basesoft' table, probably failed on loading "..filepath.." descriptor")

      -- Loading packages description table
      filepath = arguments["packages"] or oldDirectory.."/packages.desc"
      local f, err = loadfile(filepath)
      if not f then
        io.stdout:write("[ ERROR ] "); io.stdout:flush()
        error("The file '".. filepath .. "' cannot be opened or hasn't a valid syntax!")
      end
      f()
      assert(type(packages)=="table","invalid 'packages' table, probably failed on loading "..filepath.." descriptor")

      local descriptors = indexByName(mergeTables(basesoft,packages))
      basesoft = nil
      packages = nil
      return descriptors
    end,
    adaptDescriptorsToNewParser = function (descriptors)
      print("[ INFO ] Assuming the package description format used by the "..
            "Openbus 1.4.2 or earlier.")
      print("[ INFO ] Inserting a built-in source package to download (and "..
            "update) the sources of the Openbus branch ("..SVNURL..") ("..SVNDIR..").")
      -- Problem: Old versions of the 'compile' assistant downloaded the
      -- openbus-source as default.
      -- Solution: We have to insert a new description by default.
      table.insert(descriptors,1,{
        name = "openbus-source",
        url = SVNURL,
        directory = SVNDIR,
      })
      -- Problem: By default any package is placed under PRODAPP/pkg.name but
      -- some packages don't use tecmake backend (or other compile backend,
      -- what could fill the build_src third argument on build.copy) so they
      -- won't be placed correctly for the build.copy backend executes on.
      -- Solution: We have to insert the 'directory' field in that descriptions.
      if descriptors["licenses"] then
        descriptors["licenses"].directory = SVNDIR
      end
    end
}

--------------------------------------------------------------------------------
-- Main code -------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Parses package description and delegates to tools.build.<method>.run
function parseDescriptions(desc, arguments)
  ------------------------------------------------------------------------------
  -- Auxiliar local function 'compile' -----------------------------------------
  ------------------------------------------------------------------------------
  local function compile(t)
    local nameversion = util.nameversion(t)
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
      local ok, err = pcall(util.fetch_and_unpack, nameversion, t.url, t.directory)
      if not ok then
        return false, err
      end
    end
  
    assert(t.build.type, "ERROR: build.type is missing for package: "..nameversion)
    -- loading specific build methods
    ok, build_type = pcall(require, "tools.build." .. t.build.type)
    assert(ok and type(build_type) == "table","ERROR: failed initializing "..
                        "build back-end for build type: '".. t.build.type ..
                        "' for package: ".. nameversion)

    -- starting specific build methods in a protected way
    return pcall(build_type.run, t, arguments, t.directory)
  end

  for i, t in ipairs(desc) do
    -- check if already compiled in last faulty compilation 
    if not checkpoint.packages[t.name] then
      local ok, err = compile(t)
      if not ok then
        -- returning the package index of the desc table to identify
        --  the package that was the last successfully compiled
        return false, err, i
      end
    end
  end
  return true
end

function run()  
  -- Parsing arguments
  local arguments = util.parse_args(arg,[[
    --help                   : show this help
    --verbose                : turn ON the VERBOSE mode (show the system commands)
    --rebuild                : changes the default rule to rebuild the packages if
                               they're already compiled
    --force                  : forces the compile and install (i.e: you want
                               re-generate some library even it's installed
                               already, very common for debug and devel purposes)
    --list                   : list all package names from description files. When
                               '--select' is used, it'll help you to validate your choose.
    --descriptors="file1 file2 ..." : uses filenames as input for package descriptors
    --select="pkg1 pkg2 ..."        : allowchoose which packages to compile
    --profile="file1 file2 ..."     : uses a list of profile files which shoud have a list
                                      of package names inside (implicit --select usage)
    --exclude="pkg1 pkg2 ..."       : list of package names to exclude of the compile process
    --update                 : updates source codes from the repositories

   BACK-COMPATIBILITY OPTIONS:
    --compat                 : changes the parsing of the package descriptions to
                               support the old format used until the Openbus 1.4.2

   NOTES:
    The prefix '--' is optional in all options.
    So '--help' or '-help' or yet 'help' all are the same option.]],true)

  -- support to multiple values in these following options
  for _,parameterName in ipairs{"descriptors","select","profile","exclude"} do
    if arguments[parameterName] then
      local valueString = arguments[parameterName]
      arguments[parameterName] = {valueString:split("[^%s]+")}
    end
  end

  if (arguments.basesoft or arguments.packages) and not arguments.compat then
    error("The arguments --packages and --basesoft are deprecated. "..
          "Try --descriptors option. You must use --compat if you need "..
          "back-compatibility support for older formats.")
  end

  if arguments["v"] then
    arguments["verbose"] = true
  end

  print("[ INFO ] The packages will be compiled and copied to: ".. INSTALL.TOP)
  print("[ INFO ] Temporary directory used: ".. TMPDIR)

  -- Loading description files provided
  local descriptors = {}
  if arguments.compat then
    -- Back-compatibility to load both old basesoft.desc and packages.desc files
    descriptors = compat.loadDescriptors(arguments)
  else
    -- Inserting automatically all .desc files into DEPLOYDIR directory
    if not arguments.descriptors then
      arguments.descriptors = {}
      loadDescriptorsFromDir(DEPLOYDIR,arguments.descriptors)
    end
    for _,descriptorFile in ipairs(arguments["descriptors"]) do
      local tempTable = {}
      setmetatable(tempTable,{
        __index = function (t,name)
          -- global variables defined in 'tools.config' module
          if _G[name] then
            t[name] = _G[name]
            return t[name]
          end
        end})
      print("[ INFO ] Loading descriptor named '".. descriptorFile .."'")
      local f, err = loadfile(descriptorFile)
      if not f then
        error("The file '".. descriptorFile .. "' cannot be opened or isn't a valid descriptor file!")
      end
      setfenv(f,tempTable); f()
      assert(tempTable.descriptors,"'descriptors' table not defined in '"..descriptorFile.."'")
      -- ATTENTION: 
      -- current descriptor file format CONSIDER a 'descriptors' table inside
      descriptors = mergeTables(descriptors,tempTable.descriptors)
    end
    descriptors = indexByName(descriptors)
  end

  -- Including package names (using select semantics) from a profile
  if arguments["profile"] then
    assert(type(arguments.profile) == "table")
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

  -- Applying --select filter provided by user
  if arguments["select"] then
    assert(type(arguments.select) == "table")
    local filteredDescriptorsTable = {}
    for _,pkg in ipairs(arguments["select"]) do
      -- cloning the references in a new table
      if descriptors[pkg] and not filteredDescriptorsTable[pkg] then
        table.insert(filteredDescriptorsTable,descriptors[pkg])
        filteredDescriptorsTable[pkg] = descriptors[pkg]
      end
    end
    -- always updates the references
    descriptors = filteredDescriptorsTable
  end

  -- Applying --exclude filter provided by user
  if arguments["exclude"] then
    assert(type(arguments.exclude) == "table")
    -- hack to manipulate in that form: if arguments.exclude[name] then ...
    for i,pkgname in ipairs(arguments.exclude) do
      arguments.exclude[pkgname] = true
    end

    local filteredDescriptorsTable = {}
    for i,pkgdesc in ipairs(descriptors) do
     if not arguments.exclude[pkgdesc.name] then
       table.insert(filteredDescriptorsTable,pkgdesc)
       filteredDescriptorsTable[pkgdesc.name] = pkgdesc
     else
       print("[ INFO ] Excluding the package named: ", pkgdesc.name)
     end
    end
    -- always updates the references
    descriptors = filteredDescriptorsTable
  end

  -- Back-compatibility option to adapt the old package description format
  -- See the implementation of the parseDescriptions() function also.
  if arguments["compat"] then
    compat.adaptDescriptorsToNewParser(descriptors)
  end

  -- Listing packages when '--list' arguments
  if arguments["list"] then
    if #descriptors > 0 then
      print "[ INFO ] Available package descriptors to compile:"
      for _, t in ipairs(descriptors) do
        print("\t"..t.name)
      end
      return true
    else
      print("[ INFO ] No descriptor was provided.")
    end
  end

  -- Setting verbose level if requested
  if arguments["verbose"] then
    util.verbose(1)
  end
  
  -- Checkpoint checks
  if arguments.force then
    -- Removing the checkpoint file when --force is passed
    -- Assumption: the user wants to control manually
    assert(checkpoint:clean())
  else
    -- Recovering from the last package that was built successfully
    -- but only if the last compilation failed
    checkpoint:loadRecoverFile()
    if arguments.select and arguments.rebuild then
      local selected = arguments.select
      okays = checkpoint:getCorrectlyCompiled(arguments.select)
      for i, pkgname in ipairs(okays) do
        checkpoint.packages[pkgname] = nil
      end
    end
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
  -- REMEMBER: parseDescriptions returns true/false and 
  local ok, err, last = parseDescriptions(descriptors, arguments)
  if not ok then
    -- checkpoint
    assert(checkpoint:saveRecoverFile(descriptors, last))
    print("[ ERROR ] Some errors were raised. In next time, the building will"..
      " continue from the '"..descriptors[last].name.."' package."..
      " You can delete the '"..checkpoint.filename.."' file to avoid this behaviour.")
  else
    -- Removing the checkpoint file when packages compiled fine
    assert(checkpoint:clean())
    print "[ INFO ] Packages were compiled successfully !"
    print "----------------------------------------------------------------------"
  end

  -- Cleaning environment
  os.execute(myplat.cmd.rm .. TMPDIR)
  --~ I shouldn't need this!!
  --~ os.execute("cd ".. INSTALL.TOP.. "; unlink lib/lib")
  --~ os.execute("cd ".. INSTALL.TOP.. "; unlink include/include")
  --~ os.execute("cd ".. INSTALL.TOP.. "; unlink core/services/services")

  -- Closing install log files
  util.close_log()

  -- After the environment cleaning, we throw the lua error
  if not ok then
    error(err)
  end
end

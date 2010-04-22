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
  parseDescriptions(descriptors, arguments)

  -- Cleaning environment
  os.execute(myplat.cmd.rm .. TMPDIR)
  --~ I shouldn't need this!!
  --~ os.execute("cd ".. INSTALL.TOP.. "; unlink lib/lib")
  --~ os.execute("cd ".. INSTALL.TOP.. "; unlink include/include")
  --~ os.execute("cd ".. INSTALL.TOP.. "; unlink core/services/services")

  -- Closing install log files
  util.close_log()

end

#!/usr/bin/env lua5.1
package.path = "?.lua;../?.lua;" .. package.path

-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local log  = util.log

local manifest   = require "tools.manifest"
local descriptor = require "tools.descriptor"
local search     = require "tools.search"
-- Local scope
local string = require "tools.split"
local platforms = require "tools.platforms"
local myplat = platforms[config.TEC_SYSNAME]

module("tools.compile", package.seeall)

--------------------------------------------------------------------------------
-- Utility functions -----------------------------------------------------------
--------------------------------------------------------------------------------

-- Iterates a numeric ordered table and create a new index with field 'name'
local function indexByName(table)
  -- REMEMBER: 
  -- loop.ordered.set is better but it insert 'loop' module dependency
  for i,t in ipairs(table) do
    table[util.nameversion(t)] = t
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
    log.info("Descriptor '".. filename .."' found automatically")
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
local checkpoint = { filename = config.BASEDIR.."/compiler.recover", packages = {} }

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
    self.packages[ util.nameversion(descriptors[i]) ] = true
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
    v1_04 = {
      loadDescriptors = function (arguments)
        -- Earlier we used config.DEPLOYDIR = config.SVNDIR.."/tools"
        -- Hack needed to convert from SVNDIR.."/specs" to old name
        local oldDirectory = config.DEPLOYDIR:gsub("specs$","tools")
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
        log.info("Assuming the package description format used by the "..
              "Openbus 1.4.2 or earlier.")
        log.info("Inserting a built-in source package to download (and "..
              "update) the sources of the Openbus branch ("..config.SVNURL..") ("..config.SVNDIR..").")
        -- Problem: Old versions of the 'compile' assistant downloaded the
        -- openbus-source as default.
        -- Solution: We have to insert a new description by default.
        table.insert(descriptors,1,{
          name = "openbus-source",
          url = config.SVNURL,
          directory = config.SVNDIR,
        })
        -- Problem: By default any package is placed under config.PRODAPP/pkg.name-pkg.version but
        -- some packages don't use tecmake backend (or other compile backend,
        -- what could fill the build_src third argument on build.copy) so they
        -- won't be placed correctly for the build.copy backend executes on.
        -- Solution: We have to insert the 'directory' field in that descriptions.
        if descriptors["licenses"] then
          descriptors["licenses"].directory = config.SVNDIR
        end
      end,
    },
    v1_05 = {
      -- Parses package description and delegates to tools.build.<method>.run
      parseDescriptions = function (desc, arguments)
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
          if arguments.compat_v1_04 and t.source then
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
          if not checkpoint.packages[nameversion] then
            local ok, err = compile(t)
            if not ok then
              -- returning the package index of the desc table to identify
              --  the package that was the last successfully compiled
              return false, err, i
            end
          end
        end
        return true
      end,
    }
}

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
    --select="pkg1 pkg2 ..."        : chooses which packages to compile
    --profile="file1 file2 ..."     : uses a list of profile files which shoud have a list
                                      of package names inside (implicit --select usage)
    --exclude="pkg1 pkg2 ..."       : list of package names to exclude of the compile process
    --update                 : updates source codes from the repositories

   BACK-COMPATIBILITY OPTIONS:
    --compat_v1_04           : changes the parsing of the package descriptions to
                               support the format used until the OpenBus 1.4.2
    --compat_v1_05           : changes the processing of the package descriptions to
                               support the format used until the OpenBus 1.5.3
    --descriptors="file1 file2 ..." : uses filenames as input for package descriptors (requires --compat_v1_05)

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

  if (arguments.basesoft or arguments.packages) and not arguments.compat_v1_04 then
    error("The arguments --packages and --basesoft are deprecated. "..
          "Try --descriptors option. You must use --compat if you need "..
          "back-compatibility support for older formats.")
  end
  if (arguments.descriptors and not arguments.compat_v1_05) then
    error("The argument --descriptors requires the usage of --compat_v1_05 parameter "..
          "in order to proceed the processing of previous descriptor format.")
  end

  if arguments["v"] or arguments["verbose"] then
    arguments["verbose"] = true
    arguments["v"] = true
    util.verbose(1)
  end

  -- Creating the build environment
  assert(os.execute(myplat.cmd.mkdir .. config.INSTALL.TOP) == 0)
  assert(os.execute(myplat.cmd.mkdir .. config.INSTALL.LIB) == 0)
  assert(os.execute(myplat.cmd.mkdir .. config.INSTALL.BIN) == 0)
  assert(os.execute(myplat.cmd.mkdir .. config.INSTALL.INC) == 0)
  assert(os.execute(myplat.cmd.mkdir .. config.PRODAPP)     == 0)
  assert(os.execute(myplat.cmd.mkdir .. config.DOWNLOADDIR) == 0)
  assert(os.execute(myplat.cmd.mkdir .. config.PKGDIR)      == 0)
  assert(os.execute(myplat.cmd.mkdir .. config.TMPDIR)      == 0)

  -- Cleaning the temp dir to execute install rules of autotools softwares
  os.execute(myplat.cmd.rm .. config.TMPDIR .."/*")

  log.info("The packages will be compiled and copied to: ".. config.INSTALL.TOP)
  log.info("Temporary directory used: ".. config.TMPDIR)

  -- Loading description files provided
  local descriptors = {}
  if arguments.compat_v1_04 then
    -- Back-compatibility to load both old basesoft.desc and packages.desc files
    descriptors = compat.v1_04.loadDescriptors(arguments)
  elseif arguments.compat_v1_05 then
    -- Inserting automatically all .desc files into DEPLOYDIR directory
    if not arguments.descriptors then
      arguments.descriptors = {}
      loadDescriptorsFromDir(config.DEPLOYDIR,arguments.descriptors)
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
      log.info("Loading descriptor named '".. descriptorFile .."'")
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
          io.open(config.DEPLOYDIR .."/profiles/".. name,"r") or 
          io.open(config.DEPLOYDIR .."/profiles/".. name ..".profile","r"))
      
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
    for _,item in ipairs(arguments["select"]) do
      if arguments.compat_v1_05 or arguments.compat_v1_04 then
        -- cloning the references in a new table
        if descriptors[item] and not filteredDescriptorsTable[item] then
          table.insert(filteredDescriptorsTable,descriptors[item])
          filteredDescriptorsTable[item] = descriptors[item]
        end
      else
        -- testing if exists at specs repository
        local accept_multiple_results = false
        if arguments.list then
          accept_multiple_results = true
        end
        local results = search.find_suitable_rock( search.make_query(util.split_nameversion(item)), 
                                                   config.SPEC_SERVERS, accept_multiple_results )

        local function _put_on(descriptorList, pkg, spec_url)
          assert(spec_url)
          local _, filename = assert(util.download(pkg,spec_url,config.TMPDIR))
          local desc = assert(descriptor.load(filename))
          table.insert(descriptorList, desc)
          assert(os.remove(filename))
        end

        if type(results) == "table" then
          for name,versions in pairs(results) do
            for version,_ in pairs(versions) do
              local nameversion = util.nameversion{name=name,version=version}
              local query = search.make_query(name,version)
              _put_on(filteredDescriptorsTable, nameversion, search.find_suitable_rock(query, config.SPEC_SERVERS, false))
            end
          end
        elseif type(results) == "string" then
          local spec_url = results
          _put_on(filteredDescriptorsTable, item, spec_url)
        else
          log.warning("Package",item,"wasn't found in remote repositories, skipping its compilation.")
        end
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
     local nameversion = util.nameversion(pkgdesc)
     if not arguments.exclude[nameversion] then
       table.insert(filteredDescriptorsTable,pkgdesc)
       filteredDescriptorsTable[nameversion] = pkgdesc
     else
       log.info("Excluding the package named: ", nameversion)
     end
    end
    -- always updates the references
    descriptors = filteredDescriptorsTable
  end

  -- Back-compatibility option to adapt the old package description format
  -- See the implementation of the parseDescriptions() function also.
  if arguments.compat_v1_04 then
    compat.v1_04.adaptDescriptorsToNewParser(descriptors)
  end

  -- Listing packages when '--list' arguments
  if arguments["list"] then
    if #descriptors > 0 then
      log.info("Available package descriptors to compile:")
      for _, t in ipairs(descriptors) do
        log.info("\t"..util.nameversion(t))
      end
      return true
    else
      log.info("No descriptor was provided.")
    end
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

  if arguments.compat_v1_05 or arguments.compat_v1_04 then
    -- Parsing descriptions and proceed to compile & install procedures
    -- REMEMBER: parseDescriptions returns true/false and 
    local ok, err, last = compat.v1_05.parseDescriptions(descriptors, arguments)
    if not ok then
      -- checkpoint
      assert(checkpoint:saveRecoverFile(descriptors, last))
      log.error("Some errors were raised. In next time, the building will"..
        " continue from the '"..util.nameversion(descriptors[last]).."' package."..
        " You can delete the '"..checkpoint.filename.."' file to avoid this behaviour.")
    else
      -- Removing the checkpoint file when packages compiled fine
      assert(checkpoint:clean())
      log.info("Packages were compiled successfully !")
      print "----------------------------------------------------------------------"
    end
  else
    for i, selection in ipairs(descriptors) do
      assert(processing(selection,nil,arguments))
    end
  end

  -- Cleaning environment
  os.execute(myplat.cmd.rm .. config.TMPDIR)
  --~ I shouldn't need this!!
  --~ os.execute("cd ".. config.INSTALL.TOP.. "; unlink lib/lib")
  --~ os.execute("cd ".. config.INSTALL.TOP.. "; unlink include/include")
  --~ os.execute("cd ".. config.INSTALL.TOP.. "; unlink core/services/services")

  -- Closing install log files
  util.close_cache()

  -- After the environment cleaning, we throw the lua error
  if not ok then
    error(err)
  end
end

local function build_driver (spec, arguments)
  local nameversion = util.nameversion(spec)
  if not spec.build then
    spec.build = { type = "copy" }
  end
  -- loading specific build methods
  local ok, build_type = pcall(require, "tools.build." .. spec.build.type)
  assert(ok and type(build_type) == "table","[ERROR] failed initializing "..
                      "build back-end for build type: '".. spec.build.type ..
                      "' for package: ".. nameversion)

  -- starting specific build methods in a protected way
  return pcall(build_type.run, spec, arguments, spec.directory)
end

local dependencies_cache = { --[[ pkg_nameversion = { dependencies list } ]] }

function processing (pkg, specfile, arguments)
    assert(pkg and type(pkg)=="table" or (pkg == nil and type(specfile)=="string"))
    
    -- manifest loading
    local buildtree = config.PRODAPP
    local buildtree_manifest, err = manifest.load(buildtree)
    if not buildtree_manifest then
      log.warning("Rebuilding manifest from the directory hierarchy: "..buildtree)
      _, buildtree_manifest = assert(manifest.rebuild_manifest(buildtree))
    end
    
    -- package loading
    local desc
    if pkg and type(pkg) == "table" then
      desc = pkg
      specfile =  config.SPEC_SERVERS[1].."/"..util.nameversion(pkg)..".desc"
    elseif specfile ~= nil and type(specfile) == "string" then
      log.info("Fetching descriptor",specfile)

      local ok, tempfile = util.download(util.base_name(specfile),specfile,config.TMPDIR)
      assert(ok)
      desc = assert(descriptor.load(tempfile))
      assert(desc.name and desc.version)
      assert(os.remove(tempfile))
    end
    
    local nameversion = util.nameversion(desc)
    assert(buildtree_manifest)
    
    log.info("Verifying dependencies of",nameversion)
    
    local dependencies_resolved = {}
    assert(deps.fulfill_dependencies(desc, config.SPEC_SERVERS, buildtree_manifest, 
                                     processing, dependencies_resolved, arguments))

    if manifest.is_installed(buildtree_manifest, desc.name, desc.version) and
      not (arguments.force or arguments.update or arguments.rebuild) then
      log.info("Package",util.nameversion(desc),"is already compiled")
    else
      if desc.url then
        log.info("Fetching sources for",nameversion)
        local ok, err = pcall(
           util.fetch_and_unpack, nameversion, desc.url, desc.directory)
        if not ok then
          return false, err
        end
      end
      
      log.info("Initializing the compilation of",nameversion)
      assert(build_driver(desc,arguments))
      
      log.info("Updating manifest to include",nameversion)
      assert(manifest.update_manifest(desc.name, desc.version, buildtree, buildtree_manifest))
    end
    
    -- persist resolved dependencies information (used in makepack assistent, for example)
    if #dependencies_resolved > 0 then
      local metadata = assert(io.open(config.PKGDIR.."/"..nameversion..".dependencies","w"))
      for _, dep in ipairs(dependencies_resolved) do
        metadata:write(dep.."\n")
      end
      metadata:close()
    end

    return true
end
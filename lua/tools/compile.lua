#!/usr/bin/env lua5.1
package.path = "?.lua;../?.lua;" .. package.path

-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local log  = util.log

local manifest   = require "tools.manifest"
local descriptor = require "tools.descriptor"
local search     = require "tools.search"
local deps       = require "tools.deps"
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
local function mergeTables (t1, t2, replace)
  assert(t1 and t2,"both parameters must be tables")
  local k, v = next(t2)
  repeat
    if (type(k) == "number") and not replace then
      table.insert(t1,v)
    else
      t1[k] = v
    end
    k, v = next(t2,k)
  until (k == nil)
  return t1
end
-- Usefull for back-compatibility mode in descriptors that need the PUTS variables
local function importAllConfigToGlobals()
  for k,v in pairs(config) do
    _G[k] = v
  end
end
-- Reused in both back-compatibility and current compilation process
local function build_driver (spec, arguments, memoized)
  local nameversion = util.nameversion(spec)
  if not spec.build then
    spec.build = { type = "copy" }
  end

  -- per platform support
  local overrides = { config.TEC_SYSNAME, config.TEC_UNAME }
  for _, plat in ipairs(overrides) do
    if type(spec.build[plat]) == "table" then
      for context, replacement in pairs(spec.build[plat]) do
        if type(spec.build[context]) == "table" and type(replacement) == "table" then
          spec.build[context] = mergeTables(spec.build[context], replacement, true)
        else
          spec.build[context] = replacement
        end
      end
      spec.build[plat] = nil
    end
  end

  if type(spec.build.variables) == "table" then
    local pattern = "%$%((.-)%)%.?(.*)"
    for var, value in pairs(spec.build.variables) do
      if type(value) == "string" then
        -- parsing our simple dependency query language
        -- TODO: we only support table fields 'directory', 'arch' and 'repo'
        local query_pkgname, query_pkgfield = value:match(pattern)
        if query_pkgname and query_pkgfield then
          for dep, meta in pairs(memoized) do
            if (type(dep) == "table") and
              (query_pkgname == dep.name) and meta[1][query_pkgfield] then
              spec.build.variables[var] = meta[1][query_pkgfield]
              break
            end
          end
        end
      end
    end

    -- giving a good error message if the queries couldn't be translated
    local not_translated = ""
    for var, value in pairs(spec.build.variables) do
      if value:match(pattern) then
        not_translated = not_translated.." "..var.."="..value
      end
    end
    if #not_translated > 0 then
      return nil, "aborting compilation of "..nameversion..
        " because some build variables couldn't be translated:"..
        not_translated..". Check "..nameversion.." descriptor. "..
        "All names used in build.variables queries must be direct dependencies."
    end
  end

  -- loading specific build methods
  local ok, build_type = pcall(require, "tools.build." .. spec.build.type)
  if not (ok and type(build_type) == "table") then
    log.error(build_type)
    error("failed initializing build backend ".. spec.build.type .." "..
          "to compile the package ".. nameversion)
  end

  log.info("Building",nameversion,"using",spec.build.type,"driver")
  -- starting specific build methods in a protected way
  local ok, err = pcall(build_type.run, spec, arguments, spec.directory)
  if ok then
    log.info("Package",nameversion,"compiled successfully")
  end
  return ok, err
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
        local filepath = arguments.basesoft or oldDirectory.."/basesoft.desc"

        -- Loading basesoft description table
        local f, err = loadfile(filepath)
        if not f then
          log.error(err)
          return nil
        end
        f()
        if (type(basesoft) ~= "table") then 
          log.error("Invalid 'basesoft' table, file",filepath,"has an invalid syntax!")
          return nil
        end

        -- Loading packages description table
        filepath = arguments.packages or oldDirectory.."/packages.desc"
        local f, err = loadfile(filepath)
        if not f then
          log.error(err)
          return nil
        end
        f()
        if (type(packages) ~= "table") then
          log.error("Invalid 'packages' table, file",filepath,"has an invalid syntax!")
          return nil
        end

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
      -- Utility to selects all .desc from a directory
      loadDescriptorsFromDir = function (dir, list)
        assert(type(dir) == "string" and type(list) == "table","directory must be a string and list must be a table")
        local files = myplat.exec(myplat.cmd.ls.." "..dir.."/*.desc "..myplat.pipe_stderr)
        -- foreach filename...
        local nextFile = files:gmatch("[^\n]+")
        local filename = nextFile()

        if not filename then
          log.error("Package descriptors not found in",dir)
        end

        while (filename) do
          log.info("Descriptor",filename,"found automatically")
          table.insert(list,filename)
          filename = nextFile()
        end
        return list
      end,
      -- Parses package description and delegates to tools.build.<method>.run
      parseDescriptions = function (desc, arguments)
        ------------------------------------------------------------------------------
        -- Auxiliar local function 'compile' -----------------------------------------
        ------------------------------------------------------------------------------
        local function compile(t, nameversion)
          -- Back-compatibility to support the old Openbus (=< 1.4.2) package descriptions
          if arguments.compat_v1_04 and t.source then
            t.url = t.source
          end
          -- fetching and unpacking
          if t.url and arguments.update then
            local ok, err = pcall(util.fetch_and_unpack, nameversion, t.url, t.directory)
            if not ok then
              return false, err
            end
          end

          return build_driver(t, arguments)
        end

        for i, t in ipairs(desc) do
          local nameversion = util.nameversion(t)
          -- check if already compiled in last faulty compilation 
          if not checkpoint.packages[nameversion] then
            local ok, err = compile(t, nameversion)
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
  local help_msg = [[
    --help                      : show this help
    --verbose                   : turn ON the VERBOSE mode (show the system commands)
    --force                     : forces the compile and install (i.e: you want
                                  re-generate some library even it's installed
                                  already, very common for debug and devel purposes)
    --update                    : updates source codes from the repositories
    --rebuild                   : changes the default rule to rebuild the packages if
                                  they're already compiled
    --dependencies              : applies the same semantics of update, rebuild and force to all dependencies
    --select="pkg1 pkg2 ..."    : chooses which packages to compile
    --exclude="pkg1 pkg2 ..."   : list of package names to exclude of the compile process
    --list                      : list all package names to be compiled by your selection.

   BACK-COMPATIBILITY OPTIONS:
    --compat_v1_04           : changes the parsing of the package descriptions to
                               support the format used until the OpenBus 1.4.2
    --compat_v1_05           : changes the processing of the package descriptions to
                               support the format used until the OpenBus 1.5.3
    --profile="file1 file2 ..."     : uses a list of profile files which shoud have a list of
                                      package names inside (requires --compat_v1_05 or --compat_v1_04)
    --descriptors="file1 file2 ..." : uses filenames as input for package descriptors (requires --compat_v1_05)

   NOTES:
    The prefix '--' is optional in all options.
    So '--help' or '-help' or yet 'help' all are the same option.]]
  -- Parsing arguments
  local arguments = util.parse_args(arg, help_msg, true)

  -- show help instructions when no package was selected and we aren't in compatibility mode
  if not arguments.compat_v1_05 and not arguments.compat_v1_04 and not arguments.select then
    log.error("No package selected informed, missing option --select!")
    table.insert(arg,"help")
    util.parse_args(arg, help_msg)
    return false
  end

  -- support to multiple values in these following options
  for _,parameterName in ipairs{"descriptors","select","profile","exclude"} do
    if arguments[parameterName] then
      local valueString = arguments[parameterName]
      arguments[parameterName] = {valueString:split("[^%s]+")}
    end
  end

  if (arguments.basesoft or arguments.packages) and not arguments.compat_v1_04 then
    log.error("The arguments --packages and --basesoft are deprecated. "..
          "Try --descriptors option. You must use --compat if you need "..
          "back-compatibility support for older formats.")
    return false
  end
  if (arguments.descriptors and not arguments.compat_v1_05) then
    log.error("The argument --descriptors requires the usage of --compat_v1_05 parameter "..
          "in order to proceed the processing of previous descriptor format.")
    return false
  end

  if arguments.v or arguments.verbose then
    arguments.verbose = true
    arguments.v = true
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

  -- [back-compatibility] Loading of description files
  local descriptors = {}
  if arguments.compat_v1_04 then
    importAllConfigToGlobals()
    -- Back-compatibility to load both old basesoft.desc and packages.desc files
    descriptors = compat.v1_04.loadDescriptors(arguments)
    if not descriptors then
      return false
    end
    -- Back-compatibility option to adapt the old package description format
    -- See the implementation of the parseDescriptions() function also.
    compat.v1_04.adaptDescriptorsToNewParser(descriptors)
  elseif arguments.compat_v1_05 then
    importAllConfigToGlobals()
    -- Inserting automatically all .desc files into DEPLOYDIR directory
    if not arguments.descriptors then
      log.info("Loading descriptors from:",config.DEPLOYDIR)
      arguments.descriptors = {}
      compat.v1_05.loadDescriptorsFromDir(config.DEPLOYDIR, arguments.descriptors)
      if #(arguments.descriptors) == 0 then
        return false
      end
    end
    for _,descriptorFile in ipairs(arguments.descriptors) do
      local tempTable = {}
      setmetatable(tempTable,{
        __index = function (t,name)
          -- global variables defined in 'tools.config' module
          if _G[name] then
            t[name] = _G[name]
            return t[name]
          end
        end})
      log.info("Loading descriptor",descriptorFile)
      local f, err = loadfile(descriptorFile)
      if not f then
        log.error(err)
        return false
      end
      setfenv(f,tempTable); f()
      if not tempTable.descriptors then
        log.error("Invalid 'descriptors' table, file",descriptorFile,"has an invalid syntax!")
        return false
      end
      -- ATTENTION: 
      -- current descriptor file format CONSIDER a 'descriptors' table inside
      descriptors = mergeTables(descriptors,tempTable.descriptors)
    end
    descriptors = indexByName(descriptors)
  end

  -- [back-compatibility] Selection using --profile files
  if (arguments.compat_v1_05 or arguments.compat_v1_04) and arguments.profile then
    assert(type(arguments.profile) == "table")
    for _,profile in ipairs(arguments.profile) do 
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

  -- Applying --select filter
  if arguments.select then
    assert(type(arguments.select) == "table")
    local filteredDescriptorsTable = {}
    search.enable_cache()
    for _,item in ipairs(arguments.select) do
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
          if not descriptorList[pkg] then
            local _, filename = assert(util.download(pkg,spec_url,config.TMPDIR))
            local desc = assert(descriptor.load(filename))
            table.insert(descriptorList, desc)
            descriptorList[pkg] = desc
            assert(os.remove(filename))
          end
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
    search.disable_cache()
    -- always updates the references
    descriptors = filteredDescriptorsTable
  end

  -- Applying --exclude filter
  if arguments.exclude then
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
       log.info("Excluding the package:", nameversion)
     end
    end
    -- always updates the references
    descriptors = filteredDescriptorsTable
  end

  -- Listing package selection only
  if arguments.list then
    if #descriptors > 0 then
      log.info("Available package descriptors to compile:")
      search.enable_cache()
      for _, t in ipairs(descriptors) do
        log.info("\t"..util.nameversion(t))
        if t.dependencies then
          for i, dep in ipairs(t.dependencies) do
            local dep_spec_url = search.find_suitable_rock( dep, config.SPEC_SERVERS, false )
            local nameversion = util.base_name(dep_spec_url):gsub("(%.desc)","")
            if arguments.exclude and arguments.exclude[nameversion] then
              -- nothing
            else
              log.info("\t  |--> "..nameversion)
            end
          end
        end
      end
      search.disable_cache()
      return true
    else
      log.error("Package descriptors not found.")
      return false
    end
  end

  -- Compilations
  if arguments.compat_v1_05 or arguments.compat_v1_04 then
    -- Back-compatibility behaviour...
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
        local okays = checkpoint:getCorrectlyCompiled(arguments.select)
        for i, pkgname in ipairs(okays) do
          checkpoint.packages[pkgname] = nil
        end
      end
    end
    -- Parsing descriptions and proceed to compile & install procedures
    local ok, err, last = compat.v1_05.parseDescriptions(descriptors, arguments)
    if not ok then
      -- Checkpoint
      assert(checkpoint:saveRecoverFile(descriptors, last))
      if err then log.error(tostring(err)) end
      log.error("Some errors were raised in compilation process. In next time, the building will"..
        " continue from the '"..util.nameversion(descriptors[last]).."' package."..
        " You can delete the '"..checkpoint.filename.."' file to avoid this behaviour.")
      -- Closing metadata files used
      util.close_cache()
      return false
    end
    -- Removing the checkpoint file when packages compiled fine
    assert(checkpoint:clean())
  else
    -- Most updated behaviour
    search.enable_cache()
    for i, pkg in ipairs(descriptors) do
      local ok, err = pcall(processing,pkg,nil,arguments)
      if not ok then
        log.error("Failure on compilation of",util.nameversion(pkg),"software.")
        log.error(err)
        os.execute(myplat.cmd.rm .. config.TMPDIR)
        util.close_cache()
        return false
      end
    end
    search.disable_cache()
  end

  -- Cleaning environment
  os.execute(myplat.cmd.rm .. config.TMPDIR)

  -- Closing metadata files used
  util.close_cache()
  
  return true
end

local forced_reprocessing_cache = {}

function processing (pkg, specfile, arguments)
    assert(arguments)
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
      local nameversion = util.nameversion(pkg)
      if arguments.exclude and arguments.exclude[nameversion] then
        log.info("Excluding the package:", nameversion)
        return true
      end
      specfile =  config.SPEC_SERVERS[1].."/"..nameversion..".desc"
    elseif specfile ~= nil and type(specfile) == "string" then
      local nameversion = util.base_name(specfile):gsub(".desc$","")
      if arguments.exclude and arguments.exclude[nameversion] then
        log.info("Excluding the package:", nameversion)
        return true
      end
      log.info("Fetching descriptor",specfile)

      local ok, tempfile = util.download(util.base_name(specfile),specfile,config.TMPDIR)
      assert(ok)
      desc = assert(descriptor.load(tempfile))
      assert(desc.name and desc.version)
      assert(os.remove(tempfile))
    end
    
    local nameversion = util.nameversion(desc)
    
    log.info("Verifying dependencies of",nameversion)

    local function update_and_compile (desc, repository, repository_manifest, source_update, memoized)
      -- variables used here but from outside this local scope:
      -- build_driver function
      -- arguments table
      local nameversion = util.nameversion(desc)
      if desc.url and source_update then
        log.info("Fetching source code for",nameversion)
        local ok, err = pcall(
           util.fetch_and_unpack, nameversion, desc.url, desc.directory)
        if not ok then
          return false, err
        end
      end

      assert(build_driver(desc,arguments,memoized))
      
      log.debug("Updating manifest to include",nameversion)
      assert(manifest.update_manifest(desc, repository, repository_manifest))
      return true
    end

    local function forced_reprocessing (pkg, memoized, arguments)
      -- variables used here but from outside this local scope:
      -- forced_reprocessing_cache table
      local nameversion = util.nameversion(assert(pkg))

      if arguments.exclude and arguments.exclude[nameversion] then
        log.info("Excluding the package:", nameversion)
        return true
      end

      if not forced_reprocessing_cache[nameversion] then
        forced_reprocessing_cache[nameversion] = true
        local query= search.make_query(pkg.name, pkg.version)
        local specfile = search.find_suitable_rock(query, config.SPEC_SERVERS)
        assert(type(specfile) == 'string') -- fixme: unique result

        local ok, tempfile = util.download(util.base_name(specfile),specfile,config.TMPDIR)
        assert(ok)
        local desc = assert(descriptor.load(tempfile))
        assert(desc.name and desc.version)
        assert(os.remove(tempfile))

        for _, dep_query in ipairs(desc.dependencies) do
          assert(#dep_query.constraints == 1)
          --TODO: usar manifest_search(buildtree_manifest, dep_query)
          --FIXME: only works with operator '=='
          local dep = { name = dep_query.name,
                        version = dep_query.constraints[1].version.string
                      }
          memoized[dep] = manifest.get_metadata(buildtree_manifest, dep.name, dep.version)
          assert(forced_reprocessing(dep, memoized, arguments))
        end

        return update_and_compile(desc, buildtree, buildtree_manifest, arguments.update, memoized)
      end
      return true
    end

    -- force_dependencies_reprocessing is nil or a function to force compilation
    local force_dependencies_reprocessing =
      arguments.dependencies
      and (arguments.force or arguments.update or arguments.rebuild)
      and forced_reprocessing
    
    local dependencies_resolved = {}

    assert(deps.fulfill_dependencies(
        desc, config.SPEC_SERVERS, buildtree, buildtree_manifest, processing,
        force_dependencies_reprocessing, dependencies_resolved, arguments))

    buildtree_manifest = assert(manifest.load(buildtree))

    if not manifest.is_installed(buildtree_manifest, desc.name, desc.version) then
      dependencies_resolved[desc] = {{arch="installing", repo=buildtree, 
        directory=desc.directory or path.pathname(config.PRODAPP, nameversion)}}
      update_and_compile(desc, buildtree, buildtree_manifest, true, dependencies_resolved)
    elseif --[[but]] arguments.force or arguments.update or arguments.rebuild then
      dependencies_resolved[desc] = manifest.get_metadata(buildtree_manifest, desc.name, desc.version)
      update_and_compile(desc, buildtree, buildtree_manifest, arguments.update, dependencies_resolved)
    else
      log.info("Package",nameversion,"is already compiled")
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

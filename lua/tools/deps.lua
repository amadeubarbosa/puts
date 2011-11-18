-- This code is based on LuaRocks dependencies check code: 
-- see www.luarocks.org -> luarocks-2.0.6/src/luarocks/deps.lua
-- Thanks to LuaRocks Team for the insights!

require "tools.config"

-- required environment
os.execute("rm -f /tmp/*.spec")
os.execute("mkdir -p ".. PKGDIR)
ARGUMENTS={
  update=true
}
-- end

module("tools.deps", package.seeall)

-- waving puts and luarocks dependencies
util = require "tools.util"

rock_nameconcat = function(name,version)
  assert((type(name) == "string") and (type(version)== "string"))
  return name.."-"..version
end
rock_nameconcat2 = function(rock)
  return rock_nameconcat(rock.name,rock.version)
end
fetch_hook = function (specfile)
  return util.download(util.base_name(specfile),specfile,"/tmp")
end

build_hook = function (rock,arguments)
  local nameversion = rock_nameconcat(rock.name,rock.version)
  if not rock.build then
    rock.build = { type = "copy" }
  end
  -- loading specific build methods
  local ok, build_type = pcall(require, "tools.build." .. rock.build.type)
  assert(ok and type(build_type) == "table","[ERROR] failed initializing "..
                      "build back-end for build type: '".. rock.build.type ..
                      "' for package: ".. nameversion)

  -- starting specific build methods in a protected way
  return pcall(build_type.run, rock, arguments, rock.directory)
end

function load_puts_spec(file) 

  local rockspec = {os=os,require=require,assert=assert,SUNOS64_TECMAKE_FLAGS=""}
  chunk = loadfile(file)
  setfenv(chunk,rockspec)
  chunk()
--[[
  print("--- DEBUG rockspec load")
  table.foreach(rockspec,print)
  print("--- DEBUG END")
  io.read()
  ]]
  rockspec.name = rockspec.name:lower() or rockspec.package:lower()
  
  if rockspec.dependencies then
    for i = 1, #rockspec.dependencies do
       local parsed = parse_dep(rockspec.dependencies[i])
       if not parsed then
          return nil, "Parse error processing dependency '"..rockspec.dependencies[i].."'"
       end
       rockspec.dependencies[i] = parsed
    end
  else
    rockspec.dependencies = {}
  end

  return rockspec
end

compile = { 
run = function (specfile)
   print("[info] [experimental] fetching and compiling ",specfile)

   local ok, tempfile = fetch_hook(specfile)
--[[debug]]     print("[debug]",ok,tempfile)
   local puts_desc = load_puts_spec(tempfile)
--[[debug]]   print("[debug] descriptor contents:")   
--[[debug   table.foreach(puts_desc,print)
]]
   assert(fulfill_dependencies(puts_desc, compile.run))
   if puts_desc.url then
--[[debug]]   print(puts_desc.name, puts_desc.url, puts_desc.directory)     
     local ok, err = pcall(
         util.fetch_and_unpack, puts_desc.name.."-"..puts_desc.version, puts_desc.url, puts_desc.directory)
     if not ok then
       return false, err
     end
   end
   assert(build_hook(puts_desc,ARGUMENTS))
   return true
end
}

--[[ debug functions
function trace (event, line)
  local info = debug.getinfo(2)
  local funcname = info.name or ""
  local line = info.currentline or line
  if line > 0 then
    if event == "return" then
      print("[return]", funcname..":"..(line or ""))
    else
      print("[call]",funcname .. ":" .. (line or ""))
    end
  end
end

debug.sethook(trace, "c")
]]

require "tools.config"
local config = {
  TEC_UNAME=assert(_G.TEC_UNAME),
  TEC_SYSNAME=assert(_G.TEC_SYSNAME)
}

-- novas configs:
--[[
SPEC_SERVERS
MANIFEST
SPECS_DIR
]]

SPEC_SERVERS = {"file:///Users/amadeu/Work/Tecgraf/Openbus/puts-server"}
SPECS_DIR = "/tmp"

local manif_core = {}
function manif_core.get_versions(name)
  if not (MANIFEST.repository and name and MANIFEST.repository[name]) then
    return nil
  end

  local ks = {}
  for k,_ in pairs(MANIFEST.repository[name]) do
     table.insert(ks, k)
  end
  return ks
end

function manif_core.manifest_loader(path, url)
  local manifest = {}
  local loader = loadfile(path)
  assert(loader)
  setfenv(loader,manifest)
  loader()
  return manifest
end

local path = {}
path.path = function (...)
   local items = {...}
   local i = 1
   while items[i] do
      items[i] = items[i]:gsub("/*$", "")
      if items[i] == "" then
         table.remove(items, i)
      else
         i = i + 1
      end
   end
   return table.concat(items, "/")
end

path.make_url = function(pathname, name, version, arch)
   assert(type(pathname) == "string")
   assert(type(name) == "string")
   assert(type(version) == "string")
   assert(type(arch) == "string")

   local filename = name.."-"..version
   if arch == "installed" then
      filename = path.path(name, version, filename..".spec")
   elseif arch == "spec" then
      filename = filename..".spec"
   else
      filename = filename.."."..arch..".rock"
   end
   return path.path(pathname, filename)
end
path.rockspec_file = function(name, version, repo)
   assert(type(name) == "string")
   assert(type(version) == "string")
   repo = repo or SPECS_DIR
   return path.path(repo, name, version, name.."-"..version..".spec")
end

local function split_url(url)
   assert(type(url) == "string")
   
   local protocol, pathname = url:match("^([^:]*)://(.*)")
   if not protocol then
      protocol = "file"
      pathname = url
   end
   return protocol, pathname
end


local deps = {}

local util = {}
--- Print a line to standard error
util.printerr = function(...)
   io.stderr:write(table.concat({...},"\t"))
   io.stderr:write("\n")
end
util.warning = function(...)
   util.printerr("Warning: ",...)
end

local function pick_latest_version(name, versions)
   assert(type(name) == "string")
   assert(type(versions) == "table")

   local vtables = {}
   for v, _ in pairs(versions) do
      table.insert(vtables, deps.parse_version(v))
   end
   table.sort(vtables)
   local version = vtables[#vtables].string
   local items = versions[version]
   if items then
      local pick = 1
      for i, item in ipairs(items) do
         if (item.arch == 'src' and items[pick].arch == 'spec')
         or (item.arch ~= 'src' and item.arch ~= 'spec') then
            pick = i
         end
      end
      return path.make_url(items[pick].repo, name, version, items[pick].arch), name, version
   end
   return nil
end

local function load_manifest(repo_url)
   assert(type(repo_url) == "string")

   local protocol, pathname = split_url(repo_url)
   if protocol == "file" then
      pathname = path.path(pathname, "manifest")
   else -- FIXME: NOT TESTED
      local url = path.path(repo_url, "manifest")
      local name = repo_url:gsub("[/:]","_")
      print("[debug] load_manifest ",name,url)
      local ok, file = util.download(name,url, "/tmp")
      if not file then
         return nil, "Failed fetching manifest for "..repo_url
      end
      pathname = file
   end
   print("[debug] load_manifest ",pathname, repo_url)
   return manif_core.manifest_loader(pathname, repo_url)
end

local function store_result(results, name, version, arch, repo)
   assert(type(results) == "table")
   assert(type(name) == "string")
   assert(type(version) == "string")
   assert(type(arch) == "string")
   assert(type(repo) == "string")
   
   if not results[name] then results[name] = {} end
   if not results[name][version] then results[name][version] = {} end
   table.insert(results[name][version], {
      arch = arch,
      repo = repo,
      name = name,
      version = version,
   })
end

local function match_name(query, name)
   assert(type(query) == "table")
   assert(type(name) == "string")
   if query.exact_name == false then
      return name:find(query.name, 0, true) and true or false
   else
      return name == query.name
   end
end

local function store_if_match(results, repo, name, version, arch, query)
   if match_name(query, name) then
      if query.arch[arch] or query.arch["any"] then
         if match_constraints(deps.parse_version(version), query.constraints) then
            store_result(results, name, version, arch, repo)
         end
      end
   end
end

local function query_arch_as_table(query)
   local format = type(query.arch)
   if format == "table" then
      return
   elseif format == "nil" then
      local accept = {}
      accept["src"] = true
      accept["all"] = true
      accept["spec"] = true
      accept["installed"] = true
      accept[TEC_UNAME] = true
      query.arch = accept
   elseif format == "string" then
      local accept = {}
      for a in query.arch:gmatch("[%w_-]+") do
         accept[a] = true
      end
      query.arch = accept
   end
end

local function manifest_search(results, repo, query)
   assert(type(results) == "table")
   assert(type(repo) == "string")
   assert(type(query) == "table")
   
   query_arch_as_table(query)
   local manifest, err = load_manifest(repo)
   --TODO: parei aqui
   if not manifest then
      return nil, "Failed loading manifest: "..err
   end
   for name, versions in pairs(manifest.repository) do
      for version, items in pairs(versions) do
         for _, item in ipairs(items) do
            store_if_match(results, repo, name, version, item.arch, query)
         end
      end
   end
   return true
end

local search = {}
function search.search_repos(query)
   assert(type(query) == "table")

   local results = {}
   for _, repo in ipairs(SPEC_SERVERS) do
      local protocol, pathname = split_url(repo)
      if protocol == "file" then
         repo = pathname
      end
      local ok, err = manifest_search(results, repo, query)
      if not ok then
         util.warning("Failed searching manifest: "..err)
      end
   end
   return results
end

function search.find_suitable_rock(query)
   assert(type(query) == "table")
   
   local results, err = search.search_repos(query)
   if not results then
      return nil, err
   end
   local first = next(results)
   if not first then
      return nil, "No results matching query were found."
   else
     assert(not next(results, first),"[BUG] I don't understand when results could have many keys")
     return pick_latest_version(query.name, results[first])
   end
end

-- MAIN CODE

MY_PLATFORMS = { config.TEC_UNAME , config.TEC_SYSNAME }

--loadfile("/tmp/manifest")()
--MANIFEST = manifest
--manifest = nil

MANIFEST = {
  repository = {
    lua = {
      ["5.1"] = { --[[what]] },
    },
--[[    luaidl={
      ['0.8.9beta-1']={
        {
          dependencies={lua='5.1'},
          arch='not installed',
        }
      }
    },
    loop={
      ['2.3beta-1']={
        {
          dependencies={},
          arch='not installed',
        }
      }
    },
    oil={
      ['0.4beta-1']={
        {
          dependencies={loop='2.3beta-1', luasocket='2.0.2-3', luaidl='0.8.9beta-1'},
          arch='installed',
          
        }
      }
    },
    luasocket={
      ['2.0.2-3']={
        {
          dependencies={},
          arch='not installed',
        }
      }
    },    
]]    ["openldap"] = {
      ["2.4.13"] = { --[[what]] 
        
      },
    }
  }
}

local function keys(tbl)
  ks = {}
  for k,_ in pairs(tbl) do
    table.insert(ks,k)
  end
  return ks
end

local function platform_overrides(pkg)
   assert(type(pkg) == "table" or not pkg)
      
   if not pkg then return nil end
   
   overrides = {
     "build",
     "dependencies",
   }
   
  for _, platform in ipairs(MY_PLATFORMS) do
    for _, context in ipairs(overrides) do
      if pkg[context] and pkg[context][platform] then
        -- ORIGINAL DO LUAROCKS: pkg[context] = pkg[context][platform]
        -- hack 
        if type(pkg[context][platform]) == "table" then
          -- overriding all platform specific <key,values> information
          for k,v in pairs(pkg[context][platform]) do
            pkg[context][k] = v
          end
          -- overriding all numeric entries
          for i,v in ipairs(pkg[context][platform]) do
            -- respecting previous values
            pkg[context][i] = v
          end
        end
        -- fim do hack
      end
     end
  end

  return pkg
end

local operators = {
   ["=="] = "==",
   ["~="] = "~=",
   [">"] = ">",
   ["<"] = "<",
   [">="] = ">=",
   ["<="] = "<=",
   ["~>"] = "~>",
   -- plus some convenience translations
   [""] = "==",
   ["="] = "==",
   ["!="] = "~="
}

local deltas = {
   scm =    1000,
   cvs =    1000,
   rc =    -1000,
   pre =   -10000,
   beta =  -100000,
   alpha = -1000000
}

local version_mt = {
   --- Equality comparison for versions.
   -- All version numbers must be equal.
   -- If both versions have revision numbers, they must be equal;
   -- otherwise the revision number is ignored.
   -- @param v1 table: version table to compare.
   -- @param v2 table: version table to compare.
   -- @return boolean: true if they are considered equivalent.
   __eq = function(v1, v2)
      if #v1 ~= #v2 then
         return false
      end
      for i = 1, #v1 do
         if v1[i] ~= v2[i] then
            return false
         end
      end
      if v1.revision and v2.revision then
         return (v1.revision == v2.revision)
      end
      return true
   end,
   --- Size comparison for versions.
   -- All version numbers are compared.
   -- If both versions have revision numbers, they are compared;
   -- otherwise the revision number is ignored.
   -- @param v1 table: version table to compare.
   -- @param v2 table: version table to compare.
   -- @return boolean: true if v1 is considered lower than v2.
   __lt = function(v1, v2)
      for i = 1, math.max(#v1, #v2) do
         local v1i, v2i = v1[i] or 0, v2[i] or 0
         if v1i ~= v2i then
            return (v1i < v2i)
         end
      end
      if v1.revision and v2.revision then
         return (v1.revision < v2.revision)
      end
      return false
   end
}

local version_cache = {}
setmetatable(version_cache, {
   __mode = "kv"
})

function deps.parse_version(vstring)
   if not vstring then return nil end
   assert(type(vstring) == "string")

   local cached = version_cache[vstring]
   if cached then
      return cached
   end

   local version = {}
   local i = 1

   local function add_token(number)
      version[i] = version[i] and version[i] + number/100000 or number
      i = i + 1
   end
   
   -- trim leading and trailing spaces
   vstring = vstring:match("^%s*(.*)%s*$")
   version.string = vstring
   -- store revision separately if any
   local main, revision = vstring:match("(.*)%-(%d+)$")
   if revision then
      vstring = main
      version.revision = tonumber(revision)
   end
   while #vstring > 0 do
      -- extract a number
      local token, rest = vstring:match("^(%d+)[%.%-%_]*(.*)")
      if token then
         add_token(tonumber(token))
      else
         -- extract a word
         token, rest = vstring:match("^(%a+)[%.%-%_]*(.*)")
         if not token then
            util.printerr("Warning: version number '"..vstring.."' could not be parsed.")
            version[i] = 0
            break
         end
         local last = #version
         version[i] = deltas[token] or (token:byte() / 1000)
      end
      vstring = rest
   end
   setmetatable(version, version_mt)
   version_cache[vstring] = version
   return version
end

function compare_versions(a, b)
   return deps.parse_version(a) > deps.parse_version(b)
end

local function parse_constraint(input)
   assert(type(input) == "string")

   local no_upgrade, op, version, rest = input:match("^(@?)([<>=~!]*)%s*([%w%.%_%-]+)[%s,]*(.*)")
   op = operators[op]
   version = deps.parse_version(version)
   if not op or not version then return nil end
   return { op = op, version = version, no_upgrade = no_upgrade=="@" and true or nil }, rest
end

function parse_constraints(input)
   assert(type(input) == "string")

   local constraints, constraint = {}, nil
   while #input > 0 do
      constraint, input = parse_constraint(input)
      if constraint then
         table.insert(constraints, constraint)
      else
         return nil
      end
   end
   return constraints
end

function parse_dep(dep)
   assert(type(dep) == "string")

   local name, rest = dep:match("^%s*([a-zA-Z][a-zA-Z0-9%.%-%_]*)%s*(.*)")
   if not name then return nil end
   local constraints = parse_constraints(rest)
   if not constraints then return nil end
   return { name = name, constraints = constraints }
end

function show_version(v, internal)
   assert(type(v) == "table")
   assert(type(internal) == "boolean" or not internal)

   return (internal
           and table.concat(v, ":")..(v.revision and tostring(v.revision) or "")
           or v.string)
end

function show_dep(dep, internal)
   assert(type(dep) == "table")
   assert(type(internal) == "boolean" or not internal)
   
   local pretty = {}
   for _, c in ipairs(dep.constraints) do
      table.insert(pretty, c.op .. " " .. show_version(c.version, internal))
   end
   return dep.name.." "..table.concat(pretty, ", ")
end

local function partial_match(version, requested)
   assert(type(version) == "string" or type(version) == "table")
   assert(type(requested) == "string" or type(version) == "table")

   if type(version) ~= "table" then version = deps.parse_version(version) end
   if type(requested) ~= "table" then requested = deps.parse_version(requested) end
   if not version or not requested then return false end
   
   for i, ri in ipairs(requested) do
      local vi = version[i] or 0
      if ri ~= vi then return false end
   end
   if requested.revision then
      return requested.revision == version.revision
   end
   return true
end

function match_constraints(version, constraints)
   assert(type(version) == "table")
   assert(type(constraints) == "table")
   local ok = true
   setmetatable(version, version_mt)
   for _, constr in pairs(constraints) do
      local constr_version = constr.version
      setmetatable(constr.version, version_mt)
      if     constr.op == "==" then ok = version == constr_version
      elseif constr.op == "~=" then ok = version ~= constr_version
      elseif constr.op == ">"  then ok = version >  constr_version
      elseif constr.op == "<"  then ok = version <  constr_version
      elseif constr.op == ">=" then ok = version >= constr_version
      elseif constr.op == "<=" then ok = version <= constr_version
      elseif constr.op == "~>" then ok = partial_match(version, constr_version)
      end
      if not ok then break end
   end
   return ok
end


local function match_dep(dep, blacklist)
   assert(type(dep) == "table")

   local versions = manif_core.get_versions(dep.name)

   if not versions then
      return nil
   end
   if blacklist then
      local i = 1
      while versions[i] do
         if blacklist[versions[i]] then
            table.remove(versions, i)
         else
            i = i + 1
         end
      end
   end
   local candidates = {}
   for _, vstring in ipairs(versions) do
      local version = deps.parse_version(vstring)
      if match_constraints(version, dep.constraints) then
         table.insert(candidates, version)
      end
   end
   if #candidates == 0 then
      return nil
   else
      table.sort(candidates)
      return {
         name = dep.name,
         version = candidates[#candidates].string
      }
   end
end

function match_deps(rockspec, blacklist)
   assert(type(rockspec) == "table")
   assert(type(blacklist) == "table" or not blacklist)
   local matched, missing, no_upgrade = {}, {}, {}

   for _, dep in ipairs(rockspec.dependencies) do
      local found = match_dep(dep, blacklist and blacklist[dep.name] or nil)
      if found then
         if dep.name ~= "lua" then 
            matched[dep] = found
         end
      else
         if dep.constraints[1] and dep.constraints[1].no_upgrade then
            no_upgrade[dep.name] = dep
         else
            missing[dep.name] = dep
         end
      end
   end

   return matched, missing, no_upgrade
end

local function values_set(tbl)
   local set = {}
   for k, v in pairs(tbl) do
      set[v] = k 
   end
   return set
end

function fulfill_dependencies(rockspec, hook)

--   local search = require("luarocks.search")
--   local install = require("luarocks.install")

    rockspec = platform_overrides(rockspec)

   if rockspec.unsupported_platforms then
      if not platforms_set then
         platforms_set = values_set(MY_PLATFORMS)
      end
      local supported = false
      for _, plat in pairs(rockspec.unsupported_platforms) do
        if platforms_set[plat] then
          supported = false
        else
          supported = true
        end
      end
      if supported == false then
         local plats = table.concat(MY_PLATFORMS, ", ")
         return nil, "This spec for "..rockspec.name.." does not support "..plats.." platforms."
      end
   end

   local matched, missing, no_upgrade = match_deps(rockspec)

   if next(no_upgrade) then
      util.printerr("Missing dependencies for "..rockspec.name.." "..rockspec.version..":")
      for _, dep in pairs(no_upgrade) do
         util.printerr(show_dep(dep))
      end
      if next(missing) then
         for _, dep in pairs(missing) do
            util.printerr(show_dep(dep))
         end
      end
      util.printerr()
      for _, dep in pairs(no_upgrade) do
         util.printerr("This version of "..rockspec.name.." is designed for use with")
         util.printerr(show_dep(dep)..", but is configured to avoid upgrading it")
         util.printerr("automatically. Please upgrade "..dep.name.." with")
         util.printerr("   luarocks install "..dep.name)
         util.printerr("or choose an older version of "..rockspec.name.." with")
         util.printerr("   luarocks search "..rockspec.name)
      end
      return nil, "Failed matching dependencies."
   end

   if next(missing) then
      util.printerr()
      util.printerr("Missing dependencies for "..rockspec.name..":")
      for _, dep in pairs(missing) do
         util.printerr(show_dep(dep))
      end
      util.printerr()

      for _, dep in pairs(missing) do
         -- Double-check in case dependency was filled during recursion.
         if not match_dep(dep) then
            local specfile = search.find_suitable_rock(dep)
            
            if not specfile then
              print("[info] rock not found",show_dep(dep))
            else
              assert(hook(specfile))
            end
         end
      end
   end
   return true
end

--[[ NOT USED YET
function scan_deps(results, missing, manifest, name, version)
   assert(type(results) == "table")
   assert(type(missing) == "table")
   assert(type(name) == "string")
   assert(type(version) == "string")

   local fetch = require("luarocks.fetch")

   local err
   if results[name] then
      return results, missing
   end
   if not manifest.dependencies then manifest.dependencies = {} end
   local dependencies = manifest.dependencies
   if not dependencies[name] then dependencies[name] = {} end
   local dependencies_name = dependencies[name]
   local deplist = dependencies_name[version]
   local rockspec, err
   if not deplist then
      rockspec, err = fetch.load_local_rockspec(path.rockspec_file(name, version))
      if err then
         missing[name.." "..version] = true
         return results, missing
      end
      dependencies_name[version] = rockspec.dependencies
   else
      rockspec = { dependencies = deplist }
   end
   local matched, failures = match_deps(rockspec)
   for _, match in pairs(matched) do
      results, missing = scan_deps(results, missing, manifest, match.name, match.version)
   end
   if next(failures) then
      for _, failure in pairs(failures) do
         missing[show_dep(failure)] = true
      end
   end
   results[name] = version
   return results, missing
end
]]

-- main
--local rockspec, err, errcode = fetch.load_rockspec(rockspec_file)
-- input
specfile = (arg[1] and "/Users/amadeu/Work/Tecgraf/Openbus/puts-server/"..arg[1]) 
            or "/Users/amadeu/Work/Tecgraf/Openbus/puts.specs"

print("[info] [experimental] fetching and compiling ",specfile)
-- building the initial specfile
compile.run(specfile)
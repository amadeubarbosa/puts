-- This code is based on LuaRocks dependencies check code: 
-- see www.luarocks.org -> luarocks-2.0.6/src/luarocks/deps.lua
-- Thanks to LuaRocks Team for the insights!

module("tools.deps", package.seeall)

local config           = require "tools.config"
local manifest_module  = require "tools.manifest"
local path             = require "tools.path"
local util             = require "tools.util"
local log              = util.log

MY_PLATFORMS = { config.TEC_UNAME , config.TEC_SYSNAME }

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
   --IMPORTANTE: 
   --snapshot,scm,cvs garantem comparação correta contra números até 99999
   snapshot = 100000,
   scm =    100000,
   cvs =    100000,
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

function parse_version(vstring)
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
   local main, revision = vstring:match("(.*)%-(%d+)$") --TODO: revision is separated by '-'
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
            log.error("Warning: version number '"..vstring.."' could not be parsed.")
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
   return parse_version(a) > parse_version(b)
end

local function parse_constraint(input)
   assert(type(input) == "string")

   local no_upgrade, op, version, rest = input:match("^(@?)([<>=~!]*)%s*([%w%.%_%-]+)[%s,]*(.*)")
   op = operators[op]
   version = parse_version(version)
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
   if dep.constraints then
     for _, c in ipairs(dep.constraints) do
        table.insert(pretty, c.op .. " " .. show_version(c.version, internal))
     end
   else
     table.insert(pretty, "== " .. dep.version)
   end
   return dep.name.." "..table.concat(pretty, ", ")
end

local function partial_match(version, requested)
   assert(type(version) == "string" or type(version) == "table")
   assert(type(requested) == "string" or type(version) == "table")

   if type(version) ~= "table" then version = parse_version(version) end
   if type(requested) ~= "table" then requested = parse_version(requested) end
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


local function match_dep(dep, blacklist, manifest)
   assert(type(dep) == "table")

   local versions = manifest_module.get_versions(manifest,dep.name)

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
      local version = parse_version(vstring)
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

function match_deps(spec, blacklist, manifest)
   assert(type(spec) == "table")
   assert(type(blacklist) == "table" or not blacklist)
   local matched, missing, no_upgrade = {}, {}, {}

   if spec.dependencies then
     for _, dep in ipairs(spec.dependencies) do
        local found = match_dep(dep, blacklist and blacklist[dep.name] or nil, manifest)
        if found then
  --         if dep.name ~= "lua" then 
              matched[dep] = found
  --         end
        else
           if dep.constraints[1] and dep.constraints[1].no_upgrade then
              no_upgrade[dep.name] = dep
           else
              missing[dep.name] = dep
           end
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

--- Check dependencies of a package descriptor and execute a custom hook.
-- @param spec Package description which dependencies will be resolved
-- @param servers List of URLs pointing to package description servers
-- @param local_manifest Local manifest of available packages
-- @param hook Lua function to be called when some dependency is missing
-- @param memoized List of package names already resolved recursively
-- @param ... Parameteres application-specific forwarded to the hook function
-- @return boolean or (nil, string) True if no errors occurred, or 
-- nil and an error message otherwise
function fulfill_dependencies(spec, servers, local_manifest, hook, memoized, ... )
   assert(type(spec)=="table")
   assert(type(servers)=="table")
   assert(type(local_manifest)=="table")
   assert(not hook or type(hook)=="function")
   -- Specification of the hook function:
   -- function hook (first, second, ...)
   -- first  : table with the package descriptor
   -- second : string with the specfile location
   -- ...    : any application-specific
   assert(not memoized or type(memoized) == "table")

   local nameversion = util.nameversion(spec)

   spec = platform_overrides(spec)

   if spec.unsupported_platforms then
      if not platforms_set then
         platforms_set = values_set(MY_PLATFORMS)
      end
      local supported = false
      for _, plat in pairs(spec.unsupported_platforms) do
        if platforms_set[plat] then
          supported = false
        else
          supported = true
        end
      end
      if supported == false then
         local plats = table.concat(MY_PLATFORMS, ", ")
         return nil, "The descriptor of "..nameversion.." does not support "..plats.." platforms."
      end
   end

   local matched, missing, no_upgrade = match_deps(spec, nil, local_manifest)

   if next(matched) and memoized then
      for _, dep in pairs(matched) do
         table.insert(memoized,util.nameversion(dep))
      end
   end

   if next(no_upgrade) then
      log.error("Missing dependencies for "..nameversion..":")
      for _, dep in pairs(no_upgrade) do
         log.error("\t",show_dep(dep))
      end
      if next(missing) then
         for _, dep in pairs(missing) do
            log.error("\t",show_dep(dep))
         end
      end
      for _, dep in pairs(no_upgrade) do
         log.error("This version of "..spec.name.." is designed for use with")
         log.error(show_dep(dep)..", but is configured to avoid upgrading it")
         log.error("automatically.")
      end
      return nil, "Failed matching dependencies."
   end

   if next(missing) then
      log.info("Missing dependencies for "..spec.name..":")
      for _, dep in util.sortedpairs(missing) do
         log.info("\t",show_dep(dep))
      end

      for _, dep in util.sortedpairs(missing) do
         -- Double-check in case dependency was filled by recursion.
         if not match_dep(dep, nil, local_manifest) then
            local search = require "tools.search"
            local results, found_name, found_version = search.find_suitable_rock(dep, servers)
            
            if not results then
              -- when search.find_suitable_rock returns nil, second result can be an error message
              local raised_err = (found_name and " ("..tostring(found_name)..")") or ""
              return nil, "Missing dependency "..show_dep(dep).."."..raised_err
            elseif (type(results) == "table") then
              return nil, "Multiple packages available for "..show_dep(dep)..". The descriptor of "..nameversion.." must specify one of these."
            elseif (type(results) == "string") then
              log.info("The following dependency was found at servers but it isn't installed", show_dep(dep))
              if hook then 
                assert(hook(nil,results,...))
              end
              if memoized then
                table.insert(memoized,found_name.."-"..found_version)
              end
            end
         end
      end
   end
   return true
end

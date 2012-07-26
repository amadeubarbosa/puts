path     = require "tools.path"
deps     = require "tools.deps"
manifest = require "tools.manifest"
util     = require "tools.util"
log      = util.log
config   = require "tools.config"

module("tools.search",package.seeall)

-------------------------------------------------------------------------------
-- local functions
-------------------------------------------------------------------------------
local manifest_cache

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
         if item.arch == 'desc' then
            pick = i
         end
      end
      return path.make_url(items[pick].repo, name, version, items[pick].arch), name, version
   end
   return nil
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
         if deps.match_constraints(deps.parse_version(version), query.constraints) then
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
      accept["all"] = true
      accept["desc"] = true
      accept["installed"] = true
      accept[config.TEC_UNAME] = true --TODO: inclui a identificacao da plataforma do tecmake, precisa?
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
   local manifest_table, err

   if type(manifest_cache) == "table" then
     if not manifest_cache[repo] then
        manifest_table, err = manifest.load(repo)
        if manifest_table then
          manifest_cache[repo] = manifest_table
        end
      else
        manifest_table = manifest_cache[repo]
      end
   else
     manifest_table, err = manifest.load(repo)
   end

   if not manifest_table then
      return nil, "Failed loading manifest: "..tostring(err)
   end
   for name, versions in pairs(manifest_table.repository) do
      for version, items in pairs(versions) do
         for _, item in ipairs(items) do
--            assert(item.arch ~= "installed",
--            "[BUG] Package "..name.." is installed but we don't support repositories with both installed and source packages.")
            store_if_match(results, repo, name, version, item.arch, query)
         end
      end
   end

   return true
end

-------------------------------------------------------------------------------
-- public functions
-------------------------------------------------------------------------------
function enable_cache()
  manifest_cache = {}
end

function disable_cache()
  manifest_cache = nil
end

function update_cache()
  for repo, outdated_manifest in pairs(manifest_cache) do
    log.debug("Updating the cache of manifest about the repository",repo)
    manifest_cache[repo] = manifest.load(repo)
  end
end

function search_repos(query, servers)
   assert(type(query) == "table")

   local results = {}
   for _, repo in ipairs(servers) do
      local protocol, pathname = path.split_url(repo)
      if protocol == "file" then
         repo = pathname
      end
      local ok, err = manifest_search(results, repo, query)
      if not ok then
         log.warning("Failed searching manifest: "..err)
      end
   end
   return results
end

function find_suitable_rock(query, servers, all_results)
   assert(type(query) == "table")
   
   local results, err = search_repos(query, servers)

   if not results then
      return nil, err
   end
   local first = next(results)
   if not first then
      return nil, "No results matching query were found."
   else
     if next(results,first) then -- TODO: situação desconhecida
       local tmp1,tmp2,tmp3 = os.tmpname(),os.tmpname(),os.tmpname()
       assert(util.serialize_table(tmp1,query,"query"))
       assert(util.serialize_table(tmp2,results,"results"))
       assert(util.serialize_table(tmp3,servers,"servers"))
       error(string.format(
       "[bug] I don't understand what the search algorithm does when results table has many keys."..
       " Some debug information is saved at: %s %s %s",tmp1, tmp2, tmp3))
     end
     if all_results and next(results[first][(next(results[first]))]) then
       return results
     else
       return pick_latest_version(query.name, results[first])
     end
   end
end

function make_query(name, version)
   assert(type(name) == "string")
   assert(type(version) == "string" or not version)
   
   local query = {
      name = name,
      constraints = {}
   }
   if version then
      table.insert(query.constraints, { op = "==", version = deps.parse_version(version)})
   end
   return query
end

function search_buildtree(buildtree, query, results)
   assert(type(buildtree) == "string")
   assert(type(query) == "table")
   assert(type(results) == "table" or not results)
     
   if not results then
      results = {}
   end
   query_arch_as_table(query)

   for _, item in pairs(util.fs.list_dir(buildtree)) do
      local package_type
      if item:match("%.desc$") then
        item = item:gsub(".desc$","")
        package_type = "desc"
      elseif util.fs.is_dir(path.pathname(buildtree,item)) then
        package_type = "installed"
      end
      local name, version = util.split_nameversion(item)
      if (package_type == "desc" or package_type == "installed" ) and name and version then
        store_if_match(results, buildtree, name, version, package_type, query)
      else
        log.error("It wasn't possible recognize which type of package '"..item.."' is. Skipping...")
      end
   end
   return results
end
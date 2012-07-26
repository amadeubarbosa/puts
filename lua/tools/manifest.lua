
module("tools.manifest",package.seeall)

local path    = require "tools.path"
local util    = require "tools.util"
local log     = util.log
local deps    = require "tools.deps"
local search  = require "tools.search"
local config  = require "tools.config"

--------------------------------------
-- local functions
--------------------------------------
local function update_dependencies(manifest)
   for pkg, versions in pairs(manifest.repository) do
      for version, repos in pairs(versions) do
         local current = pkg.." "..version
         for _, repo in ipairs(repos) do
            if repo.arch == "installed" then
               local missing
               repo.dependencies, missing = deps.scan_deps({}, {}, manifest, pkg, version)
               repo.dependencies[pkg] = nil
               if missing then
                  for miss, _ in pairs(missing) do
                     if miss == current then
                        log.error("Tree inconsistency detected: "..current.." has no rockspec.")
                     else
                        log.error("Missing dependency for "..pkg.." "..version..": "..miss)
                     end
                  end
               end
            end
         end
      end
   end
end

local function store_results(results, manifest)
   assert(type(results) == "table")
   assert(type(manifest) == "table")

   for name, versions in pairs(results) do
      local pkgtable = manifest.repository[name] or {}
      for version, entries in pairs(versions) do
         local versiontable = {}
         for _, entry in ipairs(entries) do
            local entrytable = {}
            for k, v in pairs(entry) do
              entrytable[k] = v
            end
            table.insert(versiontable, entrytable)
         end
         pkgtable[version] = versiontable
      end
      manifest.repository[name] = pkgtable
   end
   --TODO: ainda não precisamos do recurso de update_dependencies(manifest)
   return true
end

local function local_loader(filename)
  local manifest = {}
  local loader, err = loadfile(filename)
  if not loader then
    return nil, err
  end
  setfenv(loader,manifest)
  loader()
  assert(type(manifest) == "table")
  -- TODO: chamar funçao checker() para validar a estrutura do manifesto
  return manifest
end

--------------------------------------
-- public functions
--------------------------------------
function is_installed(manifest_table, name, version)
  assert(type(manifest_table)=="table")
  
  local query = search.make_query(name,version)
  query.arch = "installed"

  if manifest_table.repository and manifest_table.repository[name] then
    for version, availables in pairs(manifest_table.repository[name]) do
      if deps.match_constraints(deps.parse_version(version), query.constraints) then
        for _, available in ipairs(availables) do
          if available.arch == query.arch then
            return true
          end
        end
      end
    end 
  end
  return false
end

function get_metadata(manifest, name, version)
  assert(manifest)
  assert(name)
  if not (manifest.repository and manifest.repository[name]) then
    return nil
  end

  for v, metadata in pairs(manifest.repository[name]) do
    if version and version == v then
      return metadata
    end
  end
end

function get_versions(manifest, name)
  assert(manifest)
  assert(name)
  if not (manifest.repository and manifest.repository[name]) then
    return nil
  end

  local versions = {}
  for version,_ in pairs(manifest.repository[name]) do
     table.insert(versions, version)
  end
  return versions
end

function load(repo_url)
   assert(type(repo_url) == "string")

   local protocol, pathname = path.split_url(repo_url)
   if protocol == "file" then
      pathname = path.pathname(pathname, "manifest")
   else
      local url = path.pathname(repo_url, "manifest")
      local fakename = repo_url:gsub("[/:]","_")
      local ok, file = util.download(fakename, url, config.TMPDIR)
      if not file then
         return nil, "Failed fetching manifest for "..repo_url
      end
      pathname = file
   end

   local manifest = local_loader(pathname)

   if protocol ~= "file" then
     os.remove(pathname)
   end
   
   return manifest
end

--- Scan a repository and output a manifest file.
-- A file called 'manifest' will be written in the root of the given
-- repository directory.
-- @param repo A local repository directory.
-- @return boolean or (nil, string): True if manifest was generated,
-- or nil and an error message.
function rebuild_manifest(repo)
   assert(type(repo) == "string")

   if not util.fs.is_dir(repo) then
      return nil, "Cannot access repository at "..repo
   end

   local query = search.make_query("")
   query.exact_name = false
   query.arch = "any"
   local results = search.search_buildtree(repo, query)
   local manifest = { repository = {}, modules = {}, commands = {} }

   local ok, err = store_results(results, manifest)
   if not ok then return nil, err end

   return util.serialize_table(path.pathname(repo, "manifest"), manifest), manifest
end

--- Load a manifest file from a local repository and add to the repository
-- information with regard to the given name and version.
-- A file called 'manifest' will be written in the root of the given
-- repository directory.
-- @param desc table: Package descriptor
-- @param repo string : Pathname of a local repository.
-- @return boolean or (nil, string): True if manifest was generated,
-- or nil and an error message.
function update_manifest(spec, repo, manifest)
   assert(type(spec) == "table")
   assert(type(spec.name) == "string" and type(spec.version) == "string")
   assert(type(repo) == "string")

   local manifest, err = manifest or load(repo)
   if not manifest then
      log.error("No existing manifest. Attempting to rebuild...")
      local ok, err = rebuild_manifest(repo)
      if not ok then
         return nil, err
      end
      manifest, err = load(repo)
      if not manifest then
         return nil, err
      end
   end

   local nameversion = util.nameversion(spec)
   local metadata = { 
      arch = "installed", repo = repo, 
      directory = spec.directory or path.pathname(config.PRODAPP, nameversion)
   }
   local results = {[spec.name] = {[spec.version] = { metadata }}}

   local ok, err = store_results(results, manifest)
   if not ok then return nil, err end

   local ok, err = util.serialize_table(path.pathname(repo, "manifest"), manifest)
   if not ok then
     return nil, err
   end
   
   search.update_cache()
   return true
end
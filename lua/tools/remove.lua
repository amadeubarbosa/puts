local config     = require "tools.config"
local util       = require "tools.util"
local manif_m    = require "tools.manifest"
local descriptor = require "tools.descriptor"
local search     = require "tools.search"
local deps       = require "tools.deps"
local platforms  = require "tools.platforms"
local myplat     = platforms[config.TEC_SYSNAME]

module("tools.remove",package.seeall)

function delete_version(name, version, local_repo, manifest, force)
  assert(type(name) == "string")
  assert(type(version) == "string")
  assert(type(local_repo) == "string")
  assert(type(manifest) == "table")

  local function check_dependents(checkName, checkVersion)
    local blacklist = { [checkName] = { [checkVersion] = true } }

    local query_all = search.make_query("")
    query_all.exact_name = false
    local installed = search.search_repos(query_all, {local_repo})
    installed[checkName][checkVersion] = nil

    local dependents = {}
    for installed_name, installed_versions in pairs(installed) do
      for installed_version, metadata in pairs(installed_versions) do
        local spec_url = search.find_suitable_rock( search.make_query(installed_name, installed_version), config.SPEC_SERVERS, false)
        if spec_url and type(spec_url) == "string" then
          local ok, tempfile = util.download(util.base_name(spec_url), spec_url, config.TMPDIR)
          assert(ok, "failed to download the "..spec_url.." from remote repositories")
          -- dowloading the descriptor of the package
          local spec = descriptor.load(tempfile)
          assert(os.remove(tempfile))

          local _, missing = deps.match_deps(spec, blacklist, manifest)
          if missing[checkName] then
            table.insert(dependents, {name = installed_name, version = installed_version})
          end
        else
          log.debug("Search results was:",spec_url)
          log.warning("Descriptor of the package "..installed_name.."-"..installed_version.." is unavailable on remote repositories.")
        end
      end
    end
    return dependents
  end

  if manifest.repository[name] then
    for v, metadata in pairs(manifest.repository[name]) do
      if v == version then
        -- check dependents
        local dependents = check_dependents(name, version)
        if #dependents == 0 or force then
          if #dependents > 0 then
            log.warning("Removal of the package",name.."-"..version,"forced.")
          end
          manifest.repository[name][version] = nil
          if not next(manifest.repository[name]) then
            manifest.repository[name] = nil
          end
        else
          return nil, "there're dependents packages installed, aborting the removal."
        end

        -- update the manifest
        local ok, err = util.serialize_table(path.pathname(local_repo, "manifest"), manifest)
        if not ok then
          return nil, err
        end

        -- remove files from build repository
        local build_dir = metadata[1].directory or path.pathname(local_repo, name.."-"..version)
        log.debug("Removing build directory",build_dir)
        assert(os.execute(myplat.cmd.rm .. build_dir) == 0)

        -- remove files from install directory
        local extensions = {".conf", ".files", ".links", ".dev.files"}
        for i, ext in ipairs(extensions) do
          local metadata_file = path.pathname(config.PKGDIR, name.."-"..version..ext)
          log.debug("Removing files from install directory, metadata been read:",metadata_file)
          local f = io.open(metadata_file, "r")
          if f then
            local iterator = f:lines()
            local installed_file = iterator()
            while installed_file do
              log.debug("\t",installed_file)
              assert(os.execute(myplat.cmd.rm .. path.pathname(config.INSTALL.TOP, installed_file)) == 0)
              installed_file = iterator()
            end
            f:close()
            -- remove metadata files from puts
            log.debug("Removing metadata file",metadata_file)
            assert(os.execute(myplat.cmd.rm .. metadata_file) == 0)
            -- remove source tarball of the package from puts
            for i, ext in ipairs{".zip",".tar.gz",".tgz",".tar.bz2"} do
              os.execute(myplat.cmd.rm .. path.pathname(config.DOWNLOADDIR, name.."-"..version..ext))
            end
          end
        end
        os.execute(myplat.cmd.rm .. path.pathname(config.PKGDIR, name.."-"..version..".dependencies"))

        return true
      end
    end
    return nil, "package "..name.."-"..version.." is not installed."
  else
    return nil, "package "..name.." is not installed."
  end

end

function run()  
  -- Parsing arguments
  local arguments = util.parse_args(arg,[[
  --help                   : show this help
  --verbose                : turn ON the VERBOSE mode (show the system commands)
  --select="pkg1 pkg2..."  : chooses which packages to remove
  --force                  : force the removal even when dependents are installed
  
  NOTES:
    The prefix '--' is optional in all options.
    So '--help' or '-help' or yet 'help' all are the same option.]],false)

  if arguments["v"] or arguments["verbose"] then
    util.verbose(1)
  end
  
  os.execute(myplat.cmd.mkdir .. config.TMPDIR)
  
  -- support to multiple values in these following options
  if arguments.select then
    local valueString = arguments.select
    arguments.select = {valueString:split("[^%s]+")}
  end

  if arguments.select then
    local manifest = manif_m.load(path.pathname(config.PRODAPP))
    assert(manifest)
    local errors = {}
    for _, selection in ipairs(arguments.select) do
      local name, version = util.split_nameversion(selection)
      if name and version then
        log.info("Trying to remove package", name.."-"..version.."...")
        local ok, err = delete_version(name, version, config.PRODAPP, manifest, arguments.force)
        if not ok then
          log.error("Package",name.."-"..version,"wasn't removed because",err)
          table.insert(errors, err)
        else
          log.info("Package",name.."-"..version, "removed successfully.")
        end
      else
        log.error("Invalid package '"..selection.."', it must be in '<name>-<version>' syntax.")
      end
    end
    os.execute(myplat.cmd.rm .. config.TMPDIR)
    if #errors == 0 then
      return true
    else
      return false
    end
  else
    os.execute(myplat.cmd.rm .. config.TMPDIR)
    return false
  end
  
  os.execute(myplat.cmd.rm .. config.TMPDIR)
  return true
end

if not package.loaded["tools.console"] then
  os.exit((run() and 0) or 1)
end

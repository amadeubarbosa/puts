local config     = require "tools.config"
local util       = require "tools.util"
local manifest   = require "tools.manifest"
local search     = require "tools.search"
local platforms  = require "tools.platforms"
local myplat     = platforms[config.TEC_SYSNAME]

module("tools.list",package.seeall)

function list(name, version, buildtree)
  local query = search.make_query(name and name:lower() or "", version)
  query.exact_name = false
  local results, err = search.search_repos(query, {buildtree})
  if not results then
    return "", err
  end

  local availables = {}
  for pkg, versions in util.sortedpairs(results) do
    for version, _ in util.sortedpairs(versions, deps.compare_versions) do
      availables[#availables+1] = pkg.."-"..version
    end
  end

  return (#availables > 0) and "\t\t"..table.concat(availables,"\n\t\t") or ""
end

function run()  
  -- Parsing arguments
  local arguments = util.parse_args(arg,[[
  --help          : show this help
  --verbose       : turn ON the VERBOSE mode (show the system commands)
  --filter        : filter to be applied while searching (default: return all packages)
  --installed     : list all installed packages in your machine
  --repository    : list all available descriptors in remote repositories
  
  NOTES:
    The prefix '--' is optional in all options.
    So '--help' or '-help' or yet 'help' all are the same option.]],false)

  if arguments["v"] or arguments["verbose"] then
    util.verbose(1)
  end

  os.execute(myplat.cmd.mkdir .. config.TMPDIR)

  local buildtree, infomsg
  if arguments.installed then
    buildtree = config.PRODAPP
    infomsg = "Listing packages installed on "..buildtree
  elseif arguments.repository then
    buildtree = config.SPEC_SERVERS[1]
    infomsg = "Listing available descriptors on repository "..buildtree
  else
    log.error("Mandatory options --repository or --installed at least.")
    os.execute(myplat.cmd.rm .. config.TMPDIR)
    return false
  end

  local str, err = list(arguments.filter, nil, buildtree)
  if #str > 0 then
    log.info(infomsg)
    print(str)
  elseif err ~= nil then 
    log.error(err)
    os.execute(myplat.cmd.rm .. config.TMPDIR)
    return false
  else
    log.info(infomsg)
    log.info("No package found".. (arguments.filter and " for --filter="..arguments.filter or "."))
  end
  
  os.execute(myplat.cmd.rm .. config.TMPDIR)
  return true
end

if not package.loaded["tools.console"] then
  os.exit((run() and 0) or 1)
end

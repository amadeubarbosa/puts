local config     = require "tools.config"
local util       = require "tools.util"
local manifest   = require "tools.manifest"
local search     = require "tools.search"
local platforms  = require "tools.platforms"
local myplat     = platforms[config.TEC_SYSNAME]

module("tools.list",package.seeall)

function list_installed(name, version, buildtree)
  
  local query = search.make_query(name and name:lower() or "", version)
  query.exact_name = false
  local results = search.search_repos(query, {buildtree})


  for pkg, versions in util.sortedpairs(results) do
    for version, _ in util.sortedpairs(versions, deps.compare_versions) do
      print("\t",pkg.."-"..version)
    end
  end
  
end

function run()  
  -- Parsing arguments
  local arguments = util.parse_args(arg,[[
  --help          : show this help
  --verbose       : turn ON the VERBOSE mode (show the system commands)
  --installed     : list all installed packages in your machine
  --repository    : list all available descriptors in remote repositories
  
  NOTES:
    The prefix '--' is optional in all options.
    So '--help' or '-help' or yet 'help' all are the same option.]],false)

  if arguments["v"] or arguments["verbose"] then
    util.verbose(1)
  end
  
  os.execute(myplat.cmd.mkdir .. config.TMPDIR)
  
  if arguments.installed then
    log.info("Packages installed on "..config.PRODAPP)
    list_installed("",nil,config.PRODAPP)
  elseif arguments.repository then
    log.info("Available descriptors on repository "..config.SPEC_SERVERS[1])
    list_installed("",nil,config.SPEC_SERVERS[1])
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

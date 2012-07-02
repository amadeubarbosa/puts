local config    = require "tools.config"
local util      = require "tools.util"
local manifest   = require "tools.manifest"
local search     = require "tools.search"

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
  --installed     : list all installed packages in your machine
  --repository    : list all available descriptors in remote repositories
  
  NOTES:
    The prefix '--' is optional in all options.
    So '--help' or '-help' or yet 'help' all are the same option.]],true)

  if arguments.installed then
    log.info("Packages installed on "..config.PRODAPP)
    list_installed("",nil,config.PRODAPP)
  elseif arguments.repository then
    log.info("Available descriptors on repository "..config.SPEC_SERVERS[1])
    list_installed("",nil,config.SPEC_SERVERS[1])
  else
    return false
  end
  
  return true
end
-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local path = require "tools.path"
local pathname = path.pathname
local util = require "tools.util"
local platforms = require "tools.platforms"
local myplat = platforms[config.TEC_SYSNAME]

module("tools.fetch.file", package.seeall)

function run(path, url)
  assert(path and url)
  if url:match("^file://") then 
    url = url:match("^file://(.*)") 
  end
  local filename = util.base_name(url)
  local download_cmd = myplat.cmd.install .." ".. url .." "..path
  return (os.execute(download_cmd) == 0), pathname(path, filename)
end

-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"
local platforms = require "tools.platforms"
local myplat = platforms[TEC_SYSNAME]

module("tools.fetch.file", package.seeall)

function run(path, url)
  assert(path and url)
  local filename = util.base_name(url)
  local download_cmd = myplat.cmd.install .." ".. url .." "..path
  return (os.execute(download_cmd) == 0), path.."/"..filename
end

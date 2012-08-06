-- Basic variables (global vars are in upper case)
require "lfs"
local config = require "tools.config"
local util = require "tools.util"
local path = require "tools.path"
local copy = require "tools.build.copy"

local platforms = require "tools.platforms"
local plat = platforms[config.TEC_SYSNAME]

module("tools.build.bjam", package.seeall)

function run(t, arguments, dir)
  local nameversion = util.nameversion(t)

  local build_dir = nil
  local src_dir = dir or path.pathname(config.PRODAPP, nameversion)

  if path.is_absolute(t.build.src) then
    build_dir = t.build.src
  else
    build_dir = path.pathname(src_dir, t.build.src or "")
  end

  assert (build_dir, "You must provide a src for building with bjam")
  util.log.debug("Bjam build directory configured to:", build_dir)

  -- os.execute(plat.cmd.mkdir .. build_dir)

  local bjam_cmd = "bjam"

  if t.build.bjam_source then
    local bjam_source = t.build.bjam_source
    if not path.is_absolute(bjam_source) then
      bjam_source = path.pathname(src_dir,bjam_source)
    end
    util.log.info("Compiling bjam at " .. bjam_source)

    local build_sh = "cd " .. bjam_source .. " && sh ./build.sh"

    util.log.debug("Calling " .. build_sh)
    r = os.execute (build_sh)

    local bjam_bin
    for entry in lfs.dir(bjam_source) do
      if string.sub(entry, 0, 4) == "bin." then
        local bin = bjam_source .. "/" .. entry
        if lfs.attributes(bin).mode == "directory" then
          bjam_bin = bin
        end
      end
    end

    assert(bjam_bin, "error because we couldn't find compiled bjam")
    bjam_cmd = bjam_bin .. "/bjam"
  end

  if t.build.boost_build_path then
    local boost_build_path = t.build.boost_build_path
    if not path.is_absolute(boost_build_path) then
      boost_build_path = path.pathname(src_dir,boost_build_path)
    end
    bjam_cmd = "BOOST_BUILD_PATH=" .. boost_build_path .. " " .. bjam_cmd
  end

  bjam_cmd = "cd " .. build_dir .. " && " .. bjam_cmd


  if t.build.features then
    for n,v in pairs(t.build.features) do
      if type(v) == "string" then
        bjam_cmd = bjam_cmd .. " " .. n .. "=" .. v
      else
        util.log.debug("Bjam build features... this is n: " .. n .. " and this is TEC_UNAME " .. config.TEC_UNAME)
      end
    end
    if t.build.features[config.TEC_UNAME] then
      for n,v in pairs(t.build.features[config.TEC_UNAME]) do
        bjam_cmd = bjam_cmd .. " " .. n .. "=" .. v
      end
    end
    if t.build.features[config.TEC_SYSNAME] then
      for n,v in pairs(t.build.features[config.TEC_SYSNAME]) do
        bjam_cmd = bjam_cmd .. " " .. n .. "=" .. v
      end
    end
  end

  for k,v in pairs(t.build.targets) do
    bjam_cmd = bjam_cmd .. " " .. v
  end

  for k,v in pairs(t.build.bjam_opts) do
    bjam_cmd = bjam_cmd .. " " .. v
  end

  util.log.debug("Running " .. bjam_cmd)

  local ret = os.execute(bjam_cmd)
  -- assert ensure that we could continue
  assert(ret == 0,"error compiling the software "..nameversion.." when performed the command '"..bjam_cmd.."'")

  -- re-using copy method to parse install_files, conf_files, dev_files
  copy.run(t,arguments,build_dir)
end


-- Basic variables (global vars are in upper case)
require "tools.config"
require "lfs"
local util = require "tools.util"
local copy = require "tools.build.copy"

local platforms = require "tools.platforms"
local plat = platforms[TEC_SYSNAME]

module("tools.build.bjam", package.seeall)

function run(t, arguments)
  print("[ INFO ] Compiling package via bjam for: ".. t.name)
  local build_dir = t.build.src
  assert (build_dir, "You must provide a src for building with bjam")
  print("[ INFO ] Compiling package via bjam for: ".. t.name .. " in " .. build_dir)

  -- os.execute(plat.cmd.mkdir .. build_dir)

  local bjam_cmd = "bjam"

  if t.build.bjam_source then
    print("[ INFO ] Compiling bjam at " .. t.build.bjam_source)

    local build_sh = "cd " .. t.build.bjam_source .. " && sh ./build.sh"

    print("[ VERBOSE ] Calling " .. build_sh)
    r = os.execute (build_sh)

    local bjam_bin
    for entry in lfs.dir(t.build.bjam_source) do
      if string.sub(entry, 0, 4) == "bin." then
        local bin = t.build.bjam_source .. "/" .. entry
        if lfs.attributes(bin).mode == "directory" then
          bjam_bin = bin
        end
      end
    end

    assert(bjam_bin, "[ERROR] Couldn't find compiled bjam")
    bjam_cmd = bjam_bin .. "/bjam"
  end

  if t.build.boost_build_path then
    bjam_cmd = "BOOST_BUILD_PATH=" .. t.build.boost_build_path .. " " .. bjam_cmd
  end

  bjam_cmd = "cd " .. build_dir .. " && " .. bjam_cmd


  if t.build.features then
    for n,v in pairs(t.build.features) do
      if type(v) == "string" then
        bjam_cmd = bjam_cmd .. " " .. n .. "=" .. v
      else
        print ("this is n: " .. n .. " and this is TEC_UNAME " .. TEC_UNAME)
      end
    end
    if t.build.features[TEC_UNAME] then
      for n,v in pairs(t.build.features[TEC_UNAME]) do
        bjam_cmd = bjam_cmd .. " " .. n .. "=" .. v
      end
    end
    if t.build.features[TEC_SYSNAME] then
      for n,v in pairs(t.build.features[TEC_SYSNAME]) do
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

  print("[ VERBOSE ] Running " .. bjam_cmd)

  local ret = os.execute(bjam_cmd)
  -- assert ensure that we could continue
  assert(ret == 0,"ERROR Compiling ".. t.name)

  -- re-using copy method to parse install_files, conf_files, dev_files
  copy.run(t,arguments,build_dir)
end


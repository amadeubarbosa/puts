-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local path = require "tools.path"
local copy = require "tools.build.copy"

-- Local scope
local string = require "tools.split"
local platforms = require "tools.platforms"
local myplat = platforms[config.TEC_SYSNAME]

module("tools.build.autotools",package.seeall)

-- Ensure tempdirs for bogus ./configure
os.execute(myplat.cmd.mkdir .. config.TMPDIR)
os.execute(myplat.cmd.mkdir .. config.TMPDIR .."/bin")
os.execute(myplat.cmd.mkdir .. config.TMPDIR .."/lib")
os.execute(myplat.cmd.mkdir .. config.TMPDIR .."/include")

-- Build dependencies check (originaly) to basesoft packages
function check_external_deps(pkgtable)
  if pkgtable.external_dependencies then
    for category,files in pairs(pkgtable.external_dependencies) do
      local var, ok = "", false
      if category == "bins" then
        -- using generic platform search
        ok = platforms:search_ldlibpath(files,"/usr/bin","PATH")
      elseif category == "libs" then
        -- using platform oriented variables
        ok = myplat:search_ldlibpath(files)
      elseif category == "includes" then
        -- using generic platform search
        ok = platforms:search_ldlibpath(files,"/usr/include","CPATH")
      end
      assert(ok,"Aborting for missing build dependencies. Missing "..
                "the following ".. category ..": ".. files)
    end
  end
end

-- Function that implements the autotools building
function run(t,arguments)
  local uname, sysname = config.TEC_UNAME, config.TEC_SYSNAME
  -- back-compatibility test
  if type(t.build[uname] or t.build[sysname]) == "string" then
    return old_run(t,arguments)
  end

  local nameversion = util.nameversion(t)

  if t.build.test_libs then
    util.log.info("Verifying if needs to compile",nameversion,"using autotools driver.")
  end

  local missing = {}
  for _,lib in ipairs(t.build.test_libs) do
    if not myplat:search_ldlibpath(lib) or arguments.force or arguments.rebuild then
      table.insert(missing, lib)
    end
  end

  if t.build.test_libs and (#missing == 0) and not arguments.force then
    util.log.info("All libraries of",nameversion,"are already installed in your system. Use --force if you wish recompile them.")
    return nil
  end

  -- verifying if all build dependencies are ok, if don't we'll abort
  check_external_deps(t)

  local build_dir = t.directory or path.pathname(config.PRODAPP, nameversion)
  local configure_cmd, build_cmd, install_cmd = "./configure", "make", "make install"

  local configure_cmd = (t.build[uname] and t.build[uname].configure) or
                        (t.build[sysname] and t.build[sysname].configure) or
                        t.build.configure or configure_cmd
  local build_cmd = (t.build[uname] and t.build[uname].compile) or
                    (t.build[sysname] and t.build[sysname].compile) or
                    t.build.compile or build_cmd
  local install_cmd = (t.build[uname] and t.build[uname].install) or
                      (t.build[sysname] and t.build[sysname].install) or 
                      t.build.install or install_cmd

  if arguments.rebuild then
    configure_cmd = "make distclean || make clean || "..
                   "gmake distclean || gmake clean; " .. configure_cmd
  end

  -- configure phase
  local cmd, ret = nil, nil
  cmd = "cd ".. build_dir .."; ".. configure_cmd
  ret = os.execute(cmd)
  assert(ret == 0,"error configuring the software ".. nameversion .." when performed the command '"..cmd.."'")

  cmd = "cd ".. build_dir .."; ".. build_cmd
  ret = os.execute(cmd)
  assert(ret == 0,"error compiling the software ".. nameversion .." when performed the command '"..cmd.."'")

  cmd = "cd ".. build_dir .."; ".. install_cmd
  ret = os.execute(cmd)
  assert(ret == 0,"error installing the software ".. nameversion .." when performed the command '"..cmd.."'")

  -- re-using copy method to parse install_files, conf_files, dev_files
  copy.run(t,arguments,build_dir)
end

function old_run(t,arguments)
  local nameversion = util.nameversion(t)
  util.log.info("Verifying if needs to compile",nameversion,"using autotools driver.")
  local plat = config.TEC_UNAME
  if not t.build[plat] then 
    plat = config.TEC_SYSNAME
    if not (t.build[plat]) then
      util.log.error("No build command provided to compile", nameversion,
      "in", config.TEC_UNAME, "or", config.TEC_SYSNAME, "platforms.")
      return nil
    end
  end

  -- when '--force' is requested we will rebuild the soft or when any
  -- test library is missing on library path
  for _,lib in ipairs(t.build.test_libs) do
    if arguments.force or arguments.rebuild or not myplat:search_ldlibpath(lib) then
      -- verifying if all build dependencies are ok, if don't we'll abort
      check_external_deps(t)

      local build_dir = config.PRODAPP .."/".. nameversion

      -- running the build and install command
      local build_cmd = t.build[plat]
      -- prepend clean target to makefile if rebuild is setted
      if arguments.rebuild then
        build_cmd = "make distclean || make clean || "..
                   "gmake distclean || gmake clean; " .. build_cmd
      end

      -- prepend the command to enter on software directory
      build_cmd = "cd ".. build_dir .."; ".. build_cmd

      util.log.info("Building",nameversion,"using autotools driver.")
      local ret = os.execute(build_cmd)
      -- assert ensure that we could continue
      assert(ret == 0,"error compiling the software ".. nameversion .." when performed the command '"..build_cmd.."'")

      -- re-using copy method to parse install_files, conf_files, dev_files
      copy.run(t,arguments,build_dir)
      break
    end
  end
end

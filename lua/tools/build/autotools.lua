-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"
local copy = require "tools.build.copy"

-- Local scope
local string = require "tools.split"
local platforms = require "tools.platforms"
local myplat = platforms[TEC_SYSNAME]

module("tools.build.autotools",package.seeall)

-- Ensure tempdirs for bogus ./configure
os.execute(myplat.cmd.mkdir .. TMPDIR)
os.execute(myplat.cmd.mkdir .. TMPDIR .."/bin")
os.execute(myplat.cmd.mkdir .. TMPDIR .."/lib")
os.execute(myplat.cmd.mkdir .. TMPDIR .."/include")

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
  print("[ INFO ] Verifying if needs to compile via autotools: "..t.name)
  local plat = TEC_UNAME
  if not t.build[plat] then 
    plat = TEC_SYSNAME
    if not (t.build[plat]) then
      print("[ WARNING ] ".. t.name..[[ has no build command provided for ']]..TEC_UNAME..[[' platforms. Skipping.]])
      return nil
    end
  end

  -- when '--force' is requested we will rebuild the soft or when any
  -- test library is missing on library path
  for _,lib in ipairs(t.build.test_libs) do
    if arguments["force"] or not myplat:search_ldlibpath(lib) then
      -- verifying if all build dependencies are ok, if don't we'll abort
      check_external_deps(t)

      local build_dir = PRODAPP .."/".. t.name .."/"

      -- running the build and install command
      local build_cmd = t.build[plat]
      -- prepend clean target to makefile if rebuild is setted
      if arguments["rebuild"] then
        build_cmd = "make distclean || make clean || "..
                   "gmake distclean || gmake clean; " .. build_cmd
      end

      -- prepend the command to enter on software directory
      build_cmd = "cd ".. build_dir .."; ".. build_cmd

      print("[ INFO ] Compiling package via autotools: "..t.name)
      local ret = os.execute(build_cmd)
      -- assert ensure that we could continue
      assert(ret == 0,"ERROR compiling the software ".. t.name .."")

      -- re-using copy method to parse install_files, conf_files, dev_files
      copy.run(t,arguments,build_dir)
      break
    end
  end
end

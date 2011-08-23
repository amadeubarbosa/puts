-- Saving important variables from LuaVM
local package_path = package.path
local package_cpath = package.cpath

package.path = "?.lua;../?.lua;" .. package.path

require "tools.config"
local string = require "tools.split"
local platforms = require "tools.platforms"
local util = require "tools.util"

module("tools.checklibdeps",package.seeall)

local checker = {}

-- Checks libraries dependencies in an OpenBus installation
function checker:libraries_deps(openbus_home)
  assert(type(openbus_home) == "string", "ERROR: Check libraries function receives a nil parameter.")
  local myplat = platforms[TEC_SYSNAME]
  assert(type(myplat.dylibext) == "string", "ERROR: Missing dynamic libraries extension information on 'platforms'.")
  
  local function rollback()
    -- Recovering important variables to LuaVM
    package.path = package_path
    package.cpath = package_cpath
  end
  
  local msg = "[ checker:libraries_deps ] "
  local check_paths = { 
    -- since OPENBUS-653
    openbus_home.."/lib",
    openbus_home.."/bin",
    -- keeping support to previous hierarchy
    openbus_home.."/libpath/"..TEC_UNAME,
    openbus_home.."/bin/"..TEC_UNAME,
    openbus_home.."/core/bin/"..TEC_UNAME,
  }
  
  print(msg.."assuming that libraries has '"..myplat.dylibext.."' extension.")
  print(msg.."assuming OpenBus installation: "..openbus_home)
  print(msg.."assuming additional path for libs: "..check_paths[1])
  package.cpath = package.cpath .. ";"..
    -- posix module uses an unusual lua_open name!
    check_paths[1] .."/libl?."..myplat.dylibext..";"..
    -- others openbus libs uses lib<name>.<dylibext>
    check_paths[1] .."/lib?."..myplat.dylibext..";"

  local misses = {}
  for _, path in ipairs(check_paths) do
    local files = {myplat.exec(myplat.cmd.ls..path..myplat.pipe_stderr):split("[^%s]+")}
    if #files == 0 then
      -- TODO:
      -- quando o pacote nÃo tem bin/TEC_UNAME ou
      -- libpath/TEC_UNAME seria gerado um erro, mas pode
      -- ser um pacote apenas com outros artefatos
      -- [questao] serÃ¡ que preciso mesmo fazer esses checks?
      --
      --rollback()
      --return nil, {}, "ERROR: Invalid OpenBus path for your platform."
    end
    -- testing all dynamic library files
    for _,file in ipairs(files) do
      local fullname = path.."/"..file
      --print("DEBUG: looking for "..file.." dynamic dependencies")
      -- returns a table containing the misses
      local miss = myplat:missing_libraries(fullname)
      -- parse plat format to represent the unknown symbols
      -- good for more information about the miss library

      -- print("DEBUG: all unknown symbols:")
      -- s = platforms[myplat]:unknown_symbols(fullname)
      -- print(s)

      if miss then
        -- maybe the openbus package will provide the miss libraries
        -- if not then we will report a system_misses list!
        local system_misses = {name = file, miss = {}}
        for i,missfile in ipairs(miss) do
          -- second check: trying use openbus libpath (that can being installed!!)
          local willbefine = io.open(check_paths[1].."/"..missfile, "r")
          if not willbefine then
            if not system_misses.miss[missfile] then
              system_misses.miss[missfile] = true
              system_misses.miss[#system_misses.miss+1] = missfile
            end
          else
            willbefine:close()
          end
        end
        -- we actually don't known these libraries
        if #system_misses.miss > 0 then
          table.insert(misses,system_misses)
        end
      end
    end
  end
  -- restore the LuaVM package variables
  rollback()
  -- return nil if we got misses
  if #misses > 0 then
    return nil, misses, "ERROR: Check your system variable that contains dynamic "..
                        "libraries paths."
  else
    print(msg.."done!")
    return true
  end
end

-- SAMPLE of a main function that could receive OPENBUS_HOME by arg table
function checker:start(openbus_home)
  -- Call the checker
  local ok, misses, errmsg = self:libraries_deps(openbus_home)

  -- Presents the results
  if not ok then
    for i,t in ipairs(misses) do
      if #t.miss > 0 then
        print("   ERROR: "..t.name.." depends on:")
        for _,libname in ipairs(t.miss) do print(libname) end
      end
     end
    return nil, errmsg
  else
    return true, "Library dependencies check DONE."
  end
end

--------------------------------------------------------------------------------
-- Main code -------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Allow be loaded from console
--~ if arg then
  --~ -- Parsing arguments
  --~ local arguments = util.parse_args(arg,[[
    --~ --help                   : show this help
    --~ --openbus=directory      : use 'directory' as OpenBus installation ]],true)
  --~ print("Searching missing dependencies...")
  --~ assert(start(arguments.openbus or os.getenv("OPENBUS_HOME")))
--~ end
return checker

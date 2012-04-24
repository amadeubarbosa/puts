-- Saving important variables from LuaVM
local package_path = package.path
local package_cpath = package.cpath

package.path = "?.lua;../?.lua;" .. package.path

local config = require "tools.config"
local string = require "tools.split"
local platforms = require "tools.platforms"
local util = require "tools.util"
local log  = util.log
local path = require "tools.path"

module("tools.checklibdeps",package.seeall)

local checker = {}

-- Checks libraries dependencies in an OpenBus installation
function checker:libraries_deps(openbus_home)
  assert(type(openbus_home) == "string", "ERROR: Check libraries function received a nil parameter.")
  local myplat = platforms[config.TEC_SYSNAME]
  assert(type(myplat.dylibext) == "table", "ERROR: Missing dynamic libraries extension information on 'platforms'.")
  
  local function rollback()
    -- Recovering important variables to LuaVM
    package.path = package_path
    package.cpath = package_cpath
  end
  
  local check_paths = { 
    -- since OPENBUS-653
    openbus_home.."/lib",
    openbus_home.."/bin",
    -- keeping support to previous hierarchy
    openbus_home.."/libpath/"..config.TEC_UNAME,
    openbus_home.."/bin/"..config.TEC_UNAME,
    openbus_home.."/core/bin/"..config.TEC_UNAME,
  }

  for i,extension in ipairs(myplat.dylibext) do
    package.cpath = package.cpath .. ";"..
      -- posix module uses an unusual lua_open name!
      check_paths[1] .."/libl?."..extension..";"..
      -- others openbus libs uses lib<name>.<dylibext>
      check_paths[1] .."/lib?."..extension
  end
  -- LUA_CPATH must end with ';'
  if #myplat.dylibext > 0 then
    package.cpath = package.cpath ..";"
  end

  local misses = {}
  local incompatibles = {}
  for _, path_to_check in ipairs(check_paths) do
    local files = util.fs.list_dir(path_to_check)
    if #files == 0 then
      -- TODO:
      -- quando o pacote nÃo tem bin/${TEC_UNAME} ou
      -- libpath/${TEC_UNAME} seria gerado um erro, mas pode
      -- ser um pacote apenas com outros artefatos
      -- [questao] serÃ¡ que preciso mesmo fazer esses checks?
      --
      --rollback()
      --return nil, {}, "ERROR: Invalid OpenBus path for your platform."
    end
    -- testing all dynamic library files
    for _,file in ipairs(files) do
      local fullname = path.pathname(path_to_check,file)
      --print("DEBUG: looking for "..file.." dynamic dependencies")
      -- returns a table containing the misses
      local miss, misstype = myplat:missing_libraries(fullname)
      -- parse plat format to represent the unknown symbols
      -- good for more information about the miss library

      -- print("DEBUG: all unknown symbols:")
      -- s = platforms[myplat]:unknown_symbols(fullname)
      -- print(s)
      if not miss then
        if type(misstype) == "string" then
          table.insert(incompatibles, { file = fullname:sub(openbus_home:len()+2), cause = misstype })
        end
      else
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
    return nil, misses, "Check your system variable that contains dynamic libraries paths."
  else
    if #incompatibles > 0 then
      return nil, incompatibles, "Some binary files are NOT compatibles with this platform."
    else
      return true
    end
  end
end

-- SAMPLE of a main function that could receive OPENBUS_HOME by arg table
function checker:start(openbus_home)
  -- Call the checker
  local ok, misses, errmsg = self:libraries_deps(openbus_home)

  -- Show the results
  if not ok then
    for i,t in ipairs(misses) do
      if t.miss and #t.miss > 0 then
        local filelist = ""
        for _,libname in ipairs(t.miss) do 
          filelist = filelist..libname.." "
        end
        log.error(util.nameversion(t).." depends of:",filelist)
      else
        log.error("File '"..t.file.."'",t.cause)
      end
     end
    return nil, errmsg
  else
    return true
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

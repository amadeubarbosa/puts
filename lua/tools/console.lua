#!/usr/bin/env lua5.1
package.path = "?.lua;../?.lua;" .. package.path

local assistant = { "compile" , "makepack" , "installer" , "hook" }

module("tools.console", package.seeall)

--------------------------------------------------------------------------------
-- Arguments manipulation ------------------------------------------------------
--------------------------------------------------------------------------------
-- ATTENTION: Important just reconfigure 'tools.config' after the configuration
-- be proceed on arguments manipulation. So we can't use 'tools.util' now!
local patt="%-?%-?(%w+)(=?)(.*)"
local valid_options = false
local reconfigure = false 
local opt,_,value
-- Poor quality manipulation, but works for now. TODO: code better
if arg[1] then
  opt,_,value = arg[1]:match(patt)
  if opt == "config" then
    if type(value) == "string" then
      reconfigure = value
    else
      print("[ ERROR ] The '--config' option must some value.")
    end
    -- removing '--config' from command line arguments table
    table.remove(arg,1)
    -- we need check again the next argument, it can be '--help'
    if arg[1] then
      opt,_,value = arg[1]:match(patt)
    else
      opt = nil
      value = nil
    end
  end
  -- If the actual argument is not '--help', it should be one of:
  if opt ~= "h" and opt ~= "help" then
    for _,assist in ipairs(assistant) do
      if opt == assist then
        valid_options = true
        break
      end
    end
    if valid_options == false then
      print("[ ERROR ] Requesting the load of an unknown assistant:",opt)
    end
  end
end
-- When '--config' is used, the reconfigure will contain the filename
if reconfigure then
  print("[ CONSOLE ] Overriding the default configuration with: ",reconfigure)
  local f,err = loadfile(reconfigure)
  if not f then
    print("[ WARNING ] The file '"..reconfigure.."' cannot be opened! Continuing with default configuration.")
  else
    f()
  end
end

-- Loading default configuration after.
-- IMPORTANT: It will define just the undefined variables!
require "tools.config"

if valid_options then
  print("[ CONSOLE ] Loading the assistant: ",opt)
  table.remove(arg,1)
  -- fixing the self-name of the script to be loaded
  arg[0] = opt
  local tools = require ("tools."..opt)
  if tools == nil then
    print("ERRO: module tools." .. opt .. " not found.")
    os.exit(1)
  end
  tools.run()
  print("[ CONSOLE ] Assistant ",opt,"has finished sucessfuly.")
  os.exit(0)
else
  print([[
 Usage: ]]..arg[0]..[[ OPTIONS SUBCOMMANDS
 Valid OPTIONS:
  --help      : show this help
  --config=filename : override the default configuration

 Valid SUBCOMMANDS:
  --compile     : execute the compile assistant
  --makepack    : execute the makepack assistant
  --installer   : execute the installer assistant
  --hook        : execute the hook assistant

 NOTES:
  The prefix '--' is optional in all options and subcommands.
  So '--help' or '-help' or yet 'help' all are the same option.

 EXAMPLES:
  1) How to use the compile?
  ]]..arg[0]..[[ --compile --help

  2) How to use the makepack?
  ]]..arg[0]..[[ --makepack --help

  3) How to use the installer?
  ]]..arg[0]..[[ --installer --help
  
  4) How to use the hook?
  ]]..arg[0]..[[ --hook --help ]])
  
  os.exit(1)
end

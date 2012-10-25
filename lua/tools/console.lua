#!/usr/bin/env lua5.1
package.path = "?.lua;../?.lua;" .. package.path

local assistants = { "compile" , "makepack" , "installer" , "hook" , "list", "remove", "make_manifest" }

module("tools.console", package.seeall)

--------------------------------------------------------------------------------
-- Arguments manipulation ------------------------------------------------------
--------------------------------------------------------------------------------
-- ATTENTION: Important just reconfigure 'tools.config' after the configuration
-- be proceed on arguments manipulation. So we can't use 'tools.util' now!
local patt="%-?%-?([%w%_]+)(=?)(.*)"
local valid_options = false
local reconfigure = false 
local opt,_,value
-- Poor quality manipulation, but works for now. TODO: code better
if arg[1] then
  opt,_,value = arg[1]:match(patt)
  if opt == "config" then
    if type(value) == "string" and value ~= "" then
      reconfigure = value
    else
      io.stderr:write("[ERROR  ] Invalid syntax. The '--config' option must have some value.\n")
      os.exit(1)
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
    for _,assistant in ipairs(assistants) do
      if opt == assistant then
        if value and value ~= "" then
          io.stderr:write("[ERROR  ] Invalid syntax. The '--"..assistant.."' subcommand must have no value.\n")
          os.exit(1)
        end
        valid_options = true
        break
      end
    end
    if valid_options == false then
      io.stderr:write("Requesting the execution of an unknown subcomand: ".. tostring(opt) .."\n")
      os.exit(1)
    end
  end
end
-- When '--config' is used, the reconfigure will contain the filename
if reconfigure then
  print("[CONSOLE] Overriding the default configuration with: ",reconfigure)
  local f,err = loadfile(reconfigure)
  if not f then
    print("[WARNING] The file '"..reconfigure.."' cannot be loaded successfuly ("..err..")!")
    print("[WARNING] Using default configuration.")
  else
    f()
  end
end

-- Loading default configuration after.
-- IMPORTANT: It will define just the undefined variables!
local config = require "tools.config"

if valid_options then
  opt = tostring(opt)

  table.remove(arg,1)
  -- fixing the self-name of the script to be loaded
  arg[0] = opt
  local tools = require ("tools.".. opt)
  if tools == nil then
    print("[ERROR  ] module tools." .. opt .." not found.")
    os.exit(1)
  end
  print("[CONSOLE] Executing the subcommand "..opt)
  local okay = tools.run()

  if not okay then
    os.exit(1)
  else
    print("[CONSOLE] Subcommand "..opt.." finished")
    os.exit(0)
  end
else
  local subcommands_help_info = {"",""}
  for i, sub in ipairs(assistants) do
    subcommands_help_info[1] = subcommands_help_info[1]..
      "  --"..sub.."\t: execute the "..sub.." subcommand\n"
    subcommands_help_info[2] = subcommands_help_info[2]..
      "  "..tostring(i)..") How to use the "..sub.."?\n  "..arg[0].." --"..sub.." --help\n"
  end
  print([[
 Usage: ]]..arg[0]..[[ OPTIONS SUBCOMMANDS
 Valid OPTIONS:
  --help      : show this help
  --config=filename : override the default configuration

 Valid SUBCOMMANDS:
]]..subcommands_help_info[1]..[[
 
 NOTES:
  The prefix '--' is optional in all options and subcommands.
  So '--help' or '-help' or yet 'help' all are the same option.

 EXAMPLES:
]]..subcommands_help_info[2])
  
  os.exit(0)
end

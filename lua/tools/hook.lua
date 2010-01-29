#!/usr/bin/env lua5.1
package.path = "?.lua;../?.lua;" .. package.path

-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"

CONFIG = "[ CONFIGURE ] "

module("tools.hook", package.seeall)

-- Configures with user interation
function wizard(template, save)
  local function parser(_,t)
    -- for a complex type delegates to __call metamethod
    if t.type == "list" then
      t.check(t, save)
    -- for a simple data asks and retrieves the answer
    else
      print(CONFIG,"Property name: ".. t.name)
      print(CONFIG,t.msg)

      if t.value == nil then
        t.value = ""
      end      
      io.write("[" .. t.value .. "]> ")      
      local var = io.read("*l")
      
      if t.type == "number" then
        var = tonumber(var)
      end
      
      if var == nil or var == "" then
        save[t.name] = t.value
      else
        assert(type(var) == t.type, "ERROR: Invalid configuration value, should be '".. t.type.."'")
        save[t.name] = var
      end
    end
  end
  -- call the parse for all fields in template table
  table.foreach(template,parser)
end

-- Checks consistency between two configuration tables
function checker(template, cfg)
  local missing = {}
  for _, t in ipairs(template) do
    -- if missing configuration marks in the missing table
    if not cfg[t.name] then
      table.insert(missing, t.name)
    elseif (type(cfg[t.name]) ~= t.type) and 
      (type(cfg[t.name]) ~= "table" or t.type ~= "list") then
      return false , "Invalid type on definition of '"..t.name.."'"
    end
  end
  -- returns a table with the missing configuration
  if #missing > 0 then
    return false, "Missing some definitions", missing
  end
  -- it's all right and no missing
  return true
end

-- Simple get to index by name
function getFieldByName(tbl, name)
  for i, t in ipairs(tbl) do
    if t.name == name then
      return t
    end
  end
  return nil
end

-- Launcher for the wizard that accepts an old configuration table
function launchWizard(template, cfg)
  assert(type(template) == "table")
  if cfg then
    -- Checks the consistency of the previous configuration
    local ok, errmsg, missing = checker(template.messages,cfg)
    if not ok then
      print(CONFIG,errmsg.. ", please complete the following properties:")
      local missing_msg = {}
      table.foreach(missing, function(i,v)
        print("  ",v)
        table.insert(missing_msg,getFieldByName(template.messages,v))
      end)
      -- Retrieves the missing configuration from user interation
      wizard(missing_msg,cfg)
    else
      print(CONFIG,"Thanks, your configuration is valid and was accepted!")
    end
  else
    cfg = {}
    wizard(template.messages,cfg)
  end
  return cfg
end

-- Loads a template table from a filename
function loadTemplate(tmplname)
  assert(type(tmplname) == "string")
  assert(not _G.messages and not _G.configure_action,
    "ERROR: Possible BUG = Lua global environment already "..
    "has _G.messages or _G.configure_action !")
  assert(loadfile(tmplname),
     "ERROR: Cannot import the configuration template '"..tmplname.."'.")()

  local template = {
    messages = _G.messages,
    configure_action = _G.configure_action,
  }
  _G.messages = nil
  _G.configure_action = nil

  -- We assume that template contains a 'messages' table
  assert(type(template.messages) == "table",
         "ERROR: Invalid template. Table 'messages' not found inside it.")
  if template.configure_action then
    assert(type(template.configure_action) == "function",
         "ERROR: Invalid template. Function 'configure_action' not found inside it.")
  end

  return template
end

function parseTemplate(filename, config, path)
  if path == nil then
    path = TMPDIR
  end
  -- parses the template
  local tmpl_table = loadTemplate(filename)
  -- launch the wizard to ask what it needs to user
  local config = launchWizard(tmpl_table, config)
  -- if all right then take a custom action (if exists)
  if not tmpl_table.configure_action then
    print(CONFIG, "WARNING: Template '"..filename.."' has no action.")
  else
    -- Takes the action planned by developer
    assert(tmpl_table.configure_action(config, path, util), "ERROR: Custom action"..
        " from template '"..filename.."' has failed!")
  end
  return config
end

function hookConfig(file)
  local dump = assert(io.open(file,"r"),
      "ERROR: Opening file '" .. file .."'."):read("*a")

  assert(loadstring("fromconsole = "..dump), "ERROR: Invalid syntax of file")()
  assert(type(fromconsole) == "table", "ERROR: Configuration should be a table")
  local result = fromconsole
  fromconsole = nil
  return result
end

function hookTemplate(template,config,path)
  config = parseTemplate(template,config,path)
  if config == nil then  
    print("ERROR: Failed parsing template '"..template.."'.")
  end
  return config
end

--------------------------------------------------------------------------------
-- Main code -------------------------------------------------------------------
--------------------------------------------------------------------------------

function run() 
  -- Parsing arguments
  local arguments = util.parse_args(arg,[[
    --help                   : show this help
    --config=filename        : use 'filename' to import a previous configuration
    --template=filename      : use 'filename' as input for run template
    --path=pathname          : path where Openbus is placed.

    NOTE:
      If you don't set argument "path". $OPENBUS_HOME will be used.

    The prefix '--' is optional in all options.
    So '--help' or '-help' or yet 'help' all are the same option.

   EXAMPLES:
    ]].. arg[0].. " --template=file")

  -- Setting verbose level if requested
  if arguments["verbose"] then
    util.verbose(1)
  end
  
  local path
  path = arguments["path"] and arguments.path or os.getenv("OPENBUS_HOME")
  assert(path,'ERRO: You need to set "path" or $OPENBUS_HOME')

  -- Cache variables
  local template, config

  if arguments.config then
    hookConfig(arguments.config)
  end

  -- Loading configuration from template file provided or from default
  if arguments.template then
    config = hookTemplate(arguments.template,config,path)
  end
end

#!/usr/bin/env lua5.1
package.path = "?.lua;../?.lua;" .. package.path

require "tools.config"
local util = require "tools.util"
local platforms = require "tools.platforms"
local myplat = platforms[TEC_SYSNAME]
local hook = require "tools.hook"

--[[ 
See important variables:
  hook.ANSWERS_FILENAME
  hook.ANSWERS_PATH
]]

--[[
  USO:
  1. gera um arquivo de template da configuracao com as respostas
  2. salva esse arquivo para o admin poder reusar
  3. repassa a tarefa de fazer a configuração real aos templates (que devem criar as configs reais)
]]

CONFIG = "[ CONFIGURE ] "
INSTALL = "[ INSTALL ] "
ERROR = "[ ERROR ] "

module("tools.installer", package.seeall)

--------------------------------------------------------------------------------
-- Main code -------------------------------------------------------------------
--------------------------------------------------------------------------------

function run()
  -- Parsing arguments
  local arguments = util.parse_args(arg,[[
    --help                   : show this help
    --config=filename        : use 'filename' to import a previous configuration
    --package=filename       : package 'filename' to unpack, configure and install
    --template=filename      : use 'filename' as input for answers
    --path=pathname          : path where the installation will be placed
    
   NOTES:
    If you give '--package' so the '--template' will be discard !
    The '--template' is useful in manual reconfiguration only !

    The prefix '--' is optional in all options.
    So '--help' or '-help' or yet 'help' all are the same option.

   EXAMPLES:
    ]].. arg[0].. " --path=~/local/openbus --package=myOpenBus.tar.gz" ..
    "--config=myPrevious.answers ]]")

  -- Setting verbose level if requested
  if arguments["verbose"] then
    util.verbose(1)
  end

  assert(arguments["path"],"Missing argument --path!")

  -- Cache variables
  -- ATTENTION: config as 'nil' is important if none previous conf is given
  local template, config

  if arguments.config then
    config = hook.hookConfig(arguments.config)
  end

  -- Loading configuration from template file provided or from default
  if arguments.template then
    config = hook.hookTemplate(arguments.template,config)
  end

  -- When no package is given assumes reconfiguration
  if arguments.package then
    if arguments.package:match(".*tar.gz$") then
      -- Starting the extraction of the package
      print(INSTALL, "Unpacking in a temporary dir '"..TMPDIR.."'...")
      assert(os.execute(myplat.cmd.mkdir .. TMPDIR) == 0)

      -- Trying extract the metadata.tar.gz from package
      print(INSTALL, "Extracting metadata.")
      local _,release,profile,arch = arguments.package:match("(.*)%-(.+)%-(.+)%-(.+).tar.gz$")
      extract_cmd = myplat.cmd.install..arguments.package.." ".. TMPDIR .."/tempinstall.tar.gz;"
      extract_cmd = extract_cmd .. " cd "..TMPDIR.." ; gzip -c -d tempinstall.tar.gz | "
      extract_cmd = extract_cmd .. myplat.cmd.tar .."-xf - metadata-"..release.."-"..profile..".tar.gz && "
      extract_cmd = extract_cmd .. "gzip -c -d metadata-"..release.."-"..profile..".tar.gz |"
      extract_cmd = extract_cmd .. myplat.cmd.tar .."-xf -"
      assert(os.execute(extract_cmd) == 0, "ERROR: '".. arguments.package .."'"..
             " is not a valid package! Please contact the administrator!")

      -- Unpacking the .tar.gz package
      -- Grant to user's configure_action functions that could operate over an
      -- instalation tree and at the end all files will be copied to real path
      assert(os.execute("cd "..TMPDIR.."; gzip -c -d tempinstall.tar.gz|".. myplat.cmd.tar .."-xf -") == 0)
      assert(os.remove(TMPDIR.."/tempinstall.tar.gz"))
      print(INSTALL, "Unpack DONE.")

      -- Verifying the openbus libraries consistency for this system
      print(INSTALL, "Searching missing dependencies...")
      local libchecker = require "tools.checklibdeps"
      local ok, msg = libchecker:start(TMPDIR)
      if not ok then error(msg.."\n '"..arguments.package.."'"..
                     " has missing dependencies! Please contact the administrator!")
      else print(INSTALL,msg) end

      print(CONFIG, "Configuring the package based on package metadata")
      local metadata_dirname = "metadata-"..release.."-"..profile
      -- Configure main step, using all .template of this package metadata
      local files = myplat.exec(myplat.cmd.ls .. TMPDIR .."/".. metadata_dirname)
      local nexttmpl = files:gmatch("%S+.template")
      local tmplname, template
      tmplname = nexttmpl()
      -- For each template ...
      while type(tmplname) == "string" do
        -- parse the template
        local filename = TMPDIR.."/"..metadata_dirname.."/"..tmplname
        config = hook.hookTemplate(filename,config)
        -- go to next template!
        tmplname = nexttmpl()
      end
      -- Removing metadata files to clean the temporary tree
      -- Maybe it's important for futher actions like uninstall or pos-install checks
      assert(os.execute(myplat.cmd.rm .. TMPDIR .."/".. metadata_dirname) == 0)
      -- Moving the temporary tree to real tree (given by user)
      assert(os.execute(myplat.cmd.mkdir .. arguments.path) == 0,
             "ERROR: The installation path is invalid or you cannot write there!")
      assert(os.execute(myplat.cmd.install .. TMPDIR .."/* ".. arguments.path) == 0)
      assert(os.execute(myplat.cmd.rm .. TMPDIR) == 0)
    else
      print(INSTALL,"Do nothing. You MUST provide a valid package filename "..
            "'<project>-<release>-<profile>-<plat>.tar.gz' to install.")
      print(INSTALL,"Please check --help for more instructions.")
      os.exit(0)
    end
  else
    --TODO: reconfiguration isn't implemented yet!
    error("ERROR: Mandatory argument --package was not provided. Aborting!")
  end

  print(CONFIG, "Configure DONE.")

  -- Persisting the answers for future usage
  util.serialize_table(hook.ANSWERS_PATH,config)
  print(INSTALL,"Saving your answers at '"..hook.ANSWERS_PATH.."', please make a backup!")

  print(INSTALL,"Installation DONE!")

end

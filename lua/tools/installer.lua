#!/usr/bin/env lua5.1
package.path = "?.lua;../?.lua;" .. package.path

local config = require "tools.config"
local util = require "tools.util"
local platforms = require "tools.platforms"
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
    ]].. arg[0].. " --path=/mydir/openbus --package=myOpenBus.tar.gz" ..
    "--config=myPrevious.answers ")

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
    local msgInvalidFilename = "'".. arguments.package .."' isn't a valid package "..
          "filename! You MUST provide something like '<release>-<profile>-<plat>.tar.gz'"..
          " and <release> information can be <prefix>-<version> or only <version>."
    if arguments.package:match(".*tar.gz$") then
      -- Parsing the package filename to extract some informations
      local _str,version,profile,arch
      _str,arch = arguments.package:match("(.+)%-(.+).tar.gz$")
      _str,profile = _str:match("(.+)%-(.+)")
      -- When filenames has no prefix we could accept them also
      if _str:match("%-") then
        _str,version = _str:match("(.+)%-(.+)")
      else
        version = _str
      end
      assert(version and profile and arch, "ERROR: "..msgInvalidFilename)
      local myplat = platforms[config.TEC_SYSNAME]
      -- Starting the extraction of the package
      print(INSTALL, "Unpacking the package in a temporary dir: "..config.TMPDIR)
      assert(os.execute(myplat.cmd.mkdir .. config.TMPDIR) == 0)

      -- Trying extract the metadata.tar.gz from package first!
      print(INSTALL, "Extracting ...")
      local metadataDirname = "metadata-"..version.."-"..profile
      local metadataFilename = metadataDirname..".tar.gz"
      local tempfile = "tempinstall.tar.gz"
      -- copy the original package to config.TMPDIR
      extract_cmd = myplat.cmd.install..arguments.package.." ".. config.TMPDIR .."/".. tempfile ..";"..
                    "cd "..config.TMPDIR.." ; gzip -c -d "..tempfile.." | ".. -- gunzipping
                    myplat.cmd.tar .."-xf - "..metadataFilename.." && ".. -- expanding the metadata.tar.gz file
                    "gzip -c -d "..metadataFilename.." |"..               -- gunzipping the metadata.tar.gz file
                    myplat.cmd.tar .."-xf -"                              -- expanding the metadata contents
      assert(os.execute(extract_cmd) == 0, "ERROR: '".. arguments.package .."'"..
             " isn't a valid package! We couldn't find the metadata file '"..metadataFilename.."'. Please contact the administrator!")

      -- Unpacking the .tar.gz package as the second step
      -- Grant to user's configure_action functions that could operate over an
      -- instalation tree and at the end all files will be copied to real path
      assert(os.execute("cd "..config.TMPDIR.."; gzip -c -d "..tempfile.." | ".. myplat.cmd.tar .."-xf -") == 0)
      assert(os.remove(config.TMPDIR.."/"..tempfile))
      print(INSTALL, "Unpack finished.")

      -- Verifying the libraries consistency for the current platform
      print(INSTALL, "Searching for missing dependencies...")
      local libchecker = require "tools.checklibdeps"
      local ok, msg = libchecker:start(config.TMPDIR)
      if not ok then error(msg.."\n '"..arguments.package.."'"..
                     " has missing dependencies! Please contact the administrator!")
      else print(INSTALL,msg) end

      print(CONFIG, "Configuring the installation using package metadata...")
      -- Configure main step, using all .template contained in package metadata
      local files = myplat.exec(myplat.cmd.ls .. config.TMPDIR .."/".. metadataDirname)
      local nexttmpl = files:gmatch("%S+.template")
      local tmplname, template
      tmplname = nexttmpl()
      -- For each template ...
      while type(tmplname) == "string" do
        -- parse the template
        local filename = config.TMPDIR.."/"..metadataDirname.."/"..tmplname
        config = hook.hookTemplate(filename,config)
        -- go to next template!
        tmplname = nexttmpl()
      end
      -- Removing metadata files to clean the temporary tree
      -- Maybe it's important for futher actions like uninstall or pos-install checks
      assert(os.execute(myplat.cmd.rm .. config.TMPDIR .."/".. metadataDirname) == 0)
      -- Moving the temporary tree to real tree (given by user)
      assert(os.execute(myplat.cmd.mkdir .. arguments.path) == 0,
             "ERROR: The installation path is invalid or you has no write permission there!")
      assert(os.execute(myplat.cmd.install .. config.TMPDIR .."/* ".. arguments.path) == 0)
      assert(os.execute(myplat.cmd.rm .. config.TMPDIR) == 0)
    else
      print(INSTALL,"Do nothing. ".. msgInvalidFilename)
      print(INSTALL,"Please check --help for other instructions.")
      os.exit(0)
    end
  else
    --TODO: reconfiguration isn't implemented yet!
    error("ERROR: Mandatory argument --package was not provided. Aborting!")
  end

  print(CONFIG,"Configuration finished.")

  if config then
    -- Persisting the answers for future usage
    util.serialize_table(hook.ANSWERS_PATH,config)
    print(INSTALL,"Saving your answers at '"..hook.ANSWERS_PATH.."', please make a backup!")
  end

  print(INSTALL,"Installation finished!")

end

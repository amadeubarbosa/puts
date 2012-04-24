#!/usr/bin/env lua5.1
package.path = "?.lua;../?.lua;" .. package.path

local tools_cfg = require "tools.config"
local util = require "tools.util"
local log  = util.log
local platforms = require "tools.platforms"
local hook = require "tools.hook"
local path = require "tools.path"

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

  if arguments["v"] or arguments["verbose"] then
    arguments["v"] = true
    arguments["verbose"] = true
    util.verbose(1)
  end

  if not arguments["path"] then
    log.error("Missing mandatory argument --path.")
    return false
  end

  -- Cache variables
  -- ATTENTION: 'configuration' as 'nil' is important when no previous configuration is given
  local template, configuration

  if arguments.config then
    configuration = hook.hookConfig(arguments.config)
  end

  -- Loading configuration from template file provided or from default
  if arguments.template then
    configuration = hook.hookTemplate(arguments.template,configuration)
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
      local myplat = platforms[tools_cfg.TEC_SYSNAME]
      -- Starting the extraction of the package
      log.info("Using the temporary directory ", tools_cfg.TMPDIR)
      assert(os.execute(myplat.cmd.mkdir .. tools_cfg.TMPDIR) == 0)

      -- Trying extract the metadata.tar.gz from package first!
      log.info("Extracting...")
      local metadataDirname = "metadata-"..version.."-"..profile
      local metadataFilename = metadataDirname..".tar.gz"
      local tempfile = "tempinstall.tar.gz"
      -- copy the original package to tools_cfg.TMPDIR
      extract_cmd = myplat.cmd.install..arguments.package.." ".. tools_cfg.TMPDIR .."/".. tempfile ..";"..
                    "cd "..tools_cfg.TMPDIR.." ; gzip -c -d "..tempfile.." | ".. -- gunzipping
                    myplat.cmd.tar .."-xf - "..metadataFilename.." && ".. -- expanding the metadata.tar.gz file
                    "gzip -c -d "..metadataFilename.." |"..               -- gunzipping the metadata.tar.gz file
                    myplat.cmd.tar .."-xf -"                              -- expanding the metadata contents
      local msgMetadataNotFound = "ERROR: '".. arguments.package .."' isn't a valid package!"..
            " Metadata metadata file '"..metadataFilename.."' missing."
      assert(os.execute(extract_cmd) == 0, msgMetadataNotFound)

      -- Unpacking the .tar.gz package as the second step
      -- Grant to user's configure_action functions that could operate over an
      -- instalation tree and at the end all files will be copied to real path
      assert(os.execute("cd "..tools_cfg.TMPDIR.."; gzip -c -d "..tempfile.." | ".. myplat.cmd.tar .."-xf -") == 0)
      assert(os.remove(path.pathname(tools_cfg.TMPDIR,tempfile)))
      log.info("Extraction finished.")

      -- Verifying the libraries consistency for the current platform
      log.info("Verifying binary compatibility for missing dependencies...")
      local libchecker = require "tools.checklibdeps"
      local ok, msgInvalidBinaries = libchecker:start(tools_cfg.TMPDIR)
      if not ok then 
        log.error(msgInvalidBinaries)
        log.error("Package '"..arguments.package.."' has missing dependencies!")
        return false
      else 
        log.info("Libraries dependencies checks finished correctly.") 
      end

      log.info("Configuring the installation using package metadata...")
      -- Configure main step, using all .template contained in package metadata
      local files = myplat.exec(myplat.cmd.ls .. tools_cfg.TMPDIR .."/".. metadataDirname)
      local nexttmpl = files:gmatch("%S+.template%.?%d*")
      local tmplname, template
      tmplname = nexttmpl()
      -- For each template ...
      while type(tmplname) == "string" do
        -- parse the template
        local filename = path.pathname(tools_cfg.TMPDIR,metadataDirname,tmplname)
        configuration = hook.hookTemplate(filename,configuration)
        -- go to next template!
        tmplname = nexttmpl()
      end
      -- Removing metadata files to clean the temporary tree
      -- Maybe it's important for futher actions like uninstall or pos-install checks
      assert(os.execute(myplat.cmd.rm .. path.pathname(tools_cfg.TMPDIR,metadataDirname)) == 0)
      -- Moving the temporary tree to real tree (given by user)
      local msgInvalidPath = "ERROR: The installation path (".. arguments.path.. ") is invalid or you don't have write permission there!"
      assert(os.execute(myplat.cmd.mkdir .. arguments.path) == 0, msgInvalidPath)
      assert(os.execute(myplat.cmd.install .. tools_cfg.TMPDIR .."/* ".. arguments.path) == 0, msgInvalidPath)
      assert(os.execute(myplat.cmd.rm .. tools_cfg.TMPDIR) == 0)
    else
      log.info("Aborting... ".. msgInvalidFilename)
      log.info("See --help for other instructions.")
      return false
    end
  else
    --TODO: reconfiguration isn't implemented yet!
    log.error("Mandatory argument --package was not provided. Aborting!")
    return false
  end

  log.info("Configuration finished.")

  if configuration then
    -- Persisting the answers for future usage
    util.serialize_table(hook.ANSWERS_PATH,configuration)
    log.info("Saving your answers at '"..hook.ANSWERS_PATH.."', please make a backup!")
  end

  log.info("Installation finished!")
  return true
end

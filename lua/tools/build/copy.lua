local config = require "tools.config"
local util = require "tools.util"
local path = require "tools.path"

-- Local scope
local string = require "tools.split"
local platforms = require "tools.platforms"
local myplat = platforms[config.TEC_SYSNAME]

module("tools.build.copy", package.seeall)

function run(t,arguments,build_dir)
  local nameversion = util.nameversion(t)
  assert(type(t) == "table")
  -- we assume a default build_dir pointing to config.PRODAPP
  if not build_dir then
    build_dir = path.pathname(config.PRODAPP,nameversion)
  end
  util.log.info("Copying files from the source directory '"..build_dir.."' ...")

  -- copying files described on packages table
  if t.install_files then
    for orig, dest in pairs(t.install_files) do
      local dir = build_dir
      -- if absolute path we assume that you know where get the files
      if orig:match("^/") then dir = "" end
      util.install(nameversion, dir.."/"..orig, dest)
    end
  end
  -- copying files related to configuration with '-conf' suffix
  if t.conf_files then
    for orig, dest in pairs(t.conf_files) do
      local dir = build_dir
      -- if absolute path we assume that you know where get the files
      if orig:match("^/") then dir = "" end
      util.install(nameversion..".conf", dir.."/"..orig, dest)
    end
  end
  -- important for configuration procedure in installation time
  if t.conf_template then
    if arguments.compat_v1_04 then
      local file = assert(io.open(t.conf_template,"r"))
      local content = file:read("*a")
      file:close()
      file = assert(io.open(config.PKGDIR.."/"..nameversion..".template","w"))
      file:write(content)
      file:close()
    else
      for i,templateName in ipairs(t.conf_template) do
        local file = assert(io.open(templateName,"r"))
        local content = file:read("*a")
        file:close()
        file = assert(io.open(config.PKGDIR.."/"..nameversion ..".template."..i, "w"))
        file:write(content)
        file:close()
      end
    end
  end
  -- copying files to special packages with '-dev' suffix
  if t.dev_files then
    for orig, dest in pairs(t.dev_files) do
      local dir = build_dir
      -- if absolute path we assume that you know where get the files
      if orig:match("^/") then dir = "" end
      util.install(nameversion..".dev", dir.."/"..orig, dest)
    end
  end
  -- linking files described on packages table
  if t.symbolic_links then
    for orig, linkpath in pairs(t.symbolic_links) do
      util.link(nameversion, orig, linkpath)
    end
  end
end

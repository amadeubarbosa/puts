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
    build_dir = path.pathname(config.PRODAPP,util.nameversion(t))
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
      util.install(nameversion.."-conf", dir.."/"..orig, dest)
    end
  end
  -- temp behaviour, future: each package as a <name>.desc and <name>.template
  -- important for configuration procedure in installation time
  if t.conf_template then
    if arguments.compat then 
      local content = assert(io.open(t.conf_template,"r")):read("*a")
      assert(io.open(config.PKGDIR.."/"..nameversion.."1.template","w")):write(content)
    else
      for i,templateName in ipairs(t.conf_template) do
        local content = assert(io.open(templateName,"r")):read("*a")
        assert(io.open(config.PKGDIR.."/"..nameversion .. i ..".template", "w")):write(content)
      end
    end
  end
  -- copying files to special packages with '-dev' suffix
  if t.dev_files then
    for orig, dest in pairs(t.dev_files) do
      local dir = build_dir
      -- if absolute path we assume that you know where get the files
      if orig:match("^/") then dir = "" end
      util.install(nameversion.."-dev", dir.."/"..orig, dest)
    end
  end
  -- linking files described on packages table
  if t.symbolic_links then
    for orig, linkpath in pairs(t.symbolic_links) do
      util.link(nameversion, orig, linkpath)
    end
  end
end

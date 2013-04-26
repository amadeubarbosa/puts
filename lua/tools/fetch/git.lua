-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local path = require "tools.path"

module("tools.fetch.git", package.seeall)

function run(dir, url)
  assert(dir and url)
  local no_out_matter = " >/dev/null 2>/dev/null"

  if os.execute("which git"..no_out_matter) ~= 0 then
    error("Git client unavailable (tried git).")
  end
  
  -- checking if dir has a previous checkout
  -- 'git remote -v show' para verificar diferenças entre a url e o workdir

  -- when dir isn't a directory, svn checkout will create it
  if os.execute("test -d " .. dir) ~= 0 then
    return (os.execute("git clone "..url.." "..dir) == 0), dir
  end

  -- svn up returns errors like 'old working copy'
  if os.execute("cd "..dir.. " && git pull ") ~= 0 then
    util.log.warning("Couldn't pull from remotes to directory '" .. dir ..
        "'. Your Git client has returned an error on pull.")
  end
  return true, dir
end


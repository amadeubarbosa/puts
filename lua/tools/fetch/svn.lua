-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local path = require "tools.path"

module("tools.fetch.svn", package.seeall)

function run(dir, url)
  assert(dir and url)
  local checkout_cmd, export_cmd, info_cmd, update_cmd = 
    "svn checkout ", "svn export ", "svn info ", "svn update "
  local no_out_matter = " >/dev/null 2>/dev/null"

  -- checking svn client
  if os.execute("which svn"..no_out_matter) ~= 0 then
    error("SVN client unavailable (tried svn).")
  end
  
  -- dummy url normalization
  url = url:match("(.+)/$") or url
  
  -- checking if dir has a previous checkout
  local previous_checkout_retcode = os.execute(info_cmd..dir..no_out_matter)
  if previous_checkout_retcode == 0 then
    local info = util.execute(info_cmd .."--xml ".. dir)
    local current = info:match("<url>(.-)</url>")
    if current ~= url then
      error(string.format("A different SVN URL (%s) has been used in '%s' directory. " ..
          "Remove '%s' directory if you need to use '%s' in this directory.", current, dir, dir, url))
    end
  end
  
  if os.execute(info_cmd .."--xml ".. url .. no_out_matter) ~= 0 then
    return false, "URL '"..url.."' is not valid or server is down."
  end

  -- when url is about a file, will use svn export
  local info = util.execute(info_cmd .."--xml ".. url)
  local kind = info:match('<entry.-kind="(%a+)"')
  if kind == "file" then
    assert(
      os.execute("test -d " .. dir) == 0,
      string.format("It wasn't possible download '%s' because it's a file and '%s' isn't a directory.", 
        url, dir))
    local filename = path.pathname(dir,util.base_name(url))    
    return (os.execute(export_cmd..url.." "..filename) == 0), filename
  end
  
  -- when dir isn't a directory, svn checkout will create it
  if os.execute("test -d " .. dir) ~= 0 then
    return (os.execute(checkout_cmd..url.." "..dir) == 0), dir
  end

  -- svn up returns errors like 'old working copy'
  if os.execute(update_cmd..dir) ~= 0 then
    util.log.warning("Couldn't update the directory '" .. dir ..
        "'. Your SVN client has returned an error on update.")
  end
  return true, dir
end


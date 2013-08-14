-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local path = require "tools.path"

module("tools.fetch.svn", package.seeall)

local info_cmd = "svn info --xml "

function get_info_url(path)
  local info = util.execute(info_cmd..path)
  local url = info:match("<url>(.-)</url>")
  return url
end

function get_info_entry_kind(path)
  local info = util.execute(info_cmd..path)
  local kind = info:match('<entry.-kind="(%a+)"')
  return kind
end

function get_info_revision(path)
  local info = util.execute(info_cmd..path)
  local rev = info:match('<commit.-revision="(%d+)"')
  return rev
end

function run(dir, url)
  assert(dir and url)
  local checkout_cmd, export_cmd, update_cmd = 
    "svn checkout ", "svn export ",  "svn update "
  local discard_output = " >/dev/null"

  -- checking svn client
  if os.execute("which svn"..discard_output) ~= 0 then
    error("SVN client not found (tried svn).")
  end
  
  -- dummy url normalization
  url = url:match("(.+)/$") or url
  
  -- checking if dir has a previous checkout
  local previous_checkout_retcode = os.execute(info_cmd..dir..discard_output)
  if previous_checkout_retcode == 0 then
    local current = get_info_url(dir)
    if current ~= url then
      error(string.format("A different SVN URL (%s) has been used in '%s' directory. " ..
          "Remove '%s' directory if you need to use '%s' in this directory.", current, dir, dir, url))
    end
  end
  
  if os.execute(info_cmd..url..discard_output) ~= 0 then
    return false, "URL '"..url.."' is not valid or server is down."
  end

  -- when url reference to a file, we will use svn export
  local kind = get_info_entry_kind(url)
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
        "'. SVN client returned an error on update.")
  end
  return true, dir
end


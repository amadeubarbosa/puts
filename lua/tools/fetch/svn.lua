-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"

module("tools.fetch.svn", package.seeall)

function run(path, url)
  assert(path and url)
  local download_cmd

  local info = util.execute("svn info ".. path)
  if os.execute("which svn >/dev/null 2>/dev/null") ~= 0 then
    error("[ ERROR ] SVN client unavailable (tried svn).")
  end
  if os.execute("test -d " .. path) ~= 0 then
    download_cmd = "svn co ".. url .." ".. path
    return (os.execute(download_cmd) == 0), path
  end
  --normalizando a url
  url = url:match("(.+)/$") or url
  if info:find(url,1,true) == nil then
    local actualRepository = info:match("URL: ([%w%c%p]*)\n") or "?"
    error(string.format("[ ERROR ] A different SVN URL (%s) has been used in '%s' directory. " ..
        "Remove '%s' directory if you need to use '%s' in this directory.", actualRepository, path, path, url))
  end

  download_cmd = "svn up ".. path
  -- allowing the svn up returns errors like 'old working copy'
  if os.execute(download_cmd) ~= 0 then
    print("[ WARNING ] Couldn't update the directory '" .. path ..
        "'. Your SVN client has returned an error during the update.")
  end
  return true, path
end


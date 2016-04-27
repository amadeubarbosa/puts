-- Basic variables (global vars are in upper case)
local config = require "tools.config"
local util = require "tools.util"
local path = require "tools.path"
local log  = util.log

module("tools.fetch.git", package.seeall)

local SSL_NO_VERIFY = "GIT_SSL_NO_VERIFY=true"

function run(dir, url)
  assert(dir and url)

  if os.execute("which git >/dev/null 2>/dev/null") ~= 0 then
    error("Git client unavailable (tried git).")
  end

  -- checking if dir has a previous checkout
  -- 'git remote -v show' para verificar diferenças entre a url e o workdir

  -- to understand URI segments: http://tools.ietf.org/html/rfc3986#section-3.3
  local segments = {}
  local segments_pos = url:find(";")
  if segments_pos ~= nil then
    local function segments2table(segment)
      local key, value = segment:match("(.*)=(.*)")
      if (key == "tag" or key == "branch") and value ~= nil then
        segments[key] = value
      else
        log.warning("Unsupported segment '"..segment.."' of URL '"..url.."'")
      end
    end
    string.gsub(url:sub(segments_pos, #url), ";([^;]+)", segments2table)
    url = url:sub(1, segments_pos-1)
  end

  if os.execute("test -d " .. dir) ~= 0 then
    local code = os.execute(SSL_NO_VERIFY.." git clone "..url.." "..dir)
    if code ~= 0 then
      return false, dir
    end
  end

  local version = segments.tag or segments.branch
  if version ~= nil then
    local code = os.execute("cd "..dir.." && git checkout "..version)
    if code ~= 0 then 
      log.warning("Git checking out to "..tostring(version)..
        " failed with return code "..tostring(code))
    end
  end

  if segments.tag == nil then
    if os.execute("cd "..dir.. " && "..SSL_NO_VERIFY.." git pull ") ~= 0 then
      log.warning("Couldn't pull from remotes to directory '" .. dir ..
          "'. Your Git client has returned an error on pull.")
    end
  end

  return true, dir
end

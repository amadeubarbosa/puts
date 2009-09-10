-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"

module("tools.fetch.svn", package.seeall)

function run(path, url)
	assert(path and url)
	local download_cmd
	if os.execute("which svn >/dev/null 2>/dev/null") == 0 then
		if os.execute("svn info ".. path .." >/dev/null 2>/dev/null") == 0 and
                   -- Versões anteriores ao svn 1.6 não retornam erros quando o path não existe.
                   os.execute("test -d " .. path) == 0 then
			download_cmd = "svn up ".. path
			-- allowing the svn up returns errors like 'old working copy'
			if os.execute(download_cmd) ~= 0 then
				print("[ WARNING ] Couldn't update the directory '"..path.."'. Your SVN client has returned an error during the update.")
			end
			return true
		else
			download_cmd = "svn co ".. url .." ".. path
		end
	end
	assert(download_cmd, "ERROR: SVN client unavailable (tried svn).")
	return (os.execute(download_cmd) == 0)
end


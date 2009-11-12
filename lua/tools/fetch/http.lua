-- Basic variables (global vars are in upper case)
require "tools.config"
local util = require "tools.util"

module("tools.fetch.http", package.seeall)

function run(path, url)
	assert(path and url)
	local filename = util.base_name(url)
	local download_cmd
	if os.execute("which wget >/dev/null 2>/dev/null") == 0 then
		download_cmd = "wget "..url
	elseif os.execute("which curl >/dev/null 2>/dev/null") == 0 then
		download_cmd = "curl -o "..filename.." "..url
	end
	assert(download_cmd, "ERROR: HTTP client unavailable (tried wget,curl).")
	download_cmd = "cd "..path.." && ".. download_cmd
	return (os.execute(download_cmd) == 0), path.."/"..filename
end

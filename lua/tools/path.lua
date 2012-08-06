module("tools.path",package.seeall)

FILE_SEPARATOR = package.config:match("%p") --platform independent cheat

function is_absolute(dir)
   return (dir and (type(dir) == "string") and 
      (dir:match("^/") or dir:match("^%a:\\")))
end

function pathname(...)
   local items = {...}
   local i = 1
   while items[i] do
      items[i] = items[i]:gsub("/*$", "")
      if items[i] == "" then
         table.remove(items, i)
      else
         i = i + 1
      end
   end
   return table.concat(items, FILE_SEPARATOR)
end

function make_url(parent, name, version, arch)
   assert(type(parent) == "string")
   assert(type(name) == "string")
   assert(type(version) == "string")
   assert(type(arch) == "string")

   local filename = name.."-"..version
   if arch == "installed" then
      filename = pathname(name, version, filename..".desc")
   elseif arch == "desc" then
      filename = filename..".desc"
   else
      filename = filename.."."..arch..".pkg"
   end
   return parent.."/"..filename
end

-- URLs should be in the "protocol://path" format.
-- For local pathnames, "file" is returned as the protocol.
-- @param url string: an URL or a local pathname.
-- @return string, string: the protocol, and the absolute pathname without the protocol.
function split_url(url)
   assert(type(url) == "string")
   
   local protocol, pathname = url:match("^([^:]*)://(.*)")
   if not protocol then
      protocol = "file"
      pathname = url
   end
   return protocol, pathname
end
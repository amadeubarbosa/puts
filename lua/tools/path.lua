local FILE_SEPARATOR = package.config:match("%p") --platform independent cheat

module("tools.path",package.seeall)

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
      filename = pathname(name, version, filename..".spec")
   elseif arch == "desc" then
      filename = filename..".desc"
   else
      filename = filename.."."..arch..".pkg"
   end
   return pathname(parent, filename):gsub(FILE_SEPARATOR,"/") --fix because use of FILE_SEPARATOR in pathname
end

function spec_file(name, version, repo)
   assert(type(name) == "string")
   assert(type(version) == "string")
   assert(type(repo) == "string")
   return pathname(repo, name, version, name.."-"..version..".spec") --FIXME: problem when http:// or similar is used as 'repo'
end

function split_url(url)
   assert(type(url) == "string")
   
   local protocol, pathname = url:match("^([^:]*)://(.*)")
   if not protocol then
      protocol = "file"
      pathname = url
   end
   return protocol, pathname
end
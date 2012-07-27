local path
if not arg[1] then
  print("\n"..
"   Usage: make_manifest.lua <path>\n"..
"   <path>   : local path to the directory with *.desc files\n")
  os.exit(1)
else
  path = arg[1]
end
manifest = require 'tools.manifest'
util = require 'tools.util'
local _, manif = manifest.rebuild_manifest(path)
for name, versions in pairs(manif.repository) do
  for version, metadatas in pairs(versions) do
    for _, meta in ipairs(metadatas) do
      if meta.arch == "desc" then
        -- cleaning metadata useless to remote repositories
        meta.repo = nil
      end
    end
  end
end

util.serialize_table(path.."/manifest", manif)
print("New manifest saved to "..path.."/manifest")

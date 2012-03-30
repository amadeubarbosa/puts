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
assert(manifest.rebuild_manifest(path))
print("New manifest saved to "..path.."/manifest")

local config = require "tools.config"
local deps = require "tools.deps"

module("tools.descriptor",package.seeall)

-- TODO:
-- * criar descriptor.template e descriptor.checker semelhante ao que faz o LuaRocks para validar o descritor
-- 
function load( filename )
  local f, luacode, chunk, spec

  -- loading puts descriptor
  func, err = loadfile(filename)
  if not func then return nil, err end
  spec = {}
  setmetatable(spec, 
  { __index = function(t,key)
      if config[key] then
        t[key] = config[key] --cache on spec table itself
        return t[key]
      end
    end
  })
  setfenv(func, spec)
  local ok, err = pcall(func)
  if not ok then return nil, err end

  spec.name = spec.name:lower() or spec.package:lower()

  -- parsing dependencies  
  if spec.dependencies then
    for i = 1, #spec.dependencies do
       local parsed = deps.parse_dep(spec.dependencies[i])
       if not parsed then
          return nil, "Parse error processing dependency '"..spec.dependencies[i].."'"
       end
       spec.dependencies[i] = parsed
    end
  else
    spec.dependencies = {}
  end

  return spec
end

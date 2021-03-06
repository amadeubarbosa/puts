local config = require "tools.config"
local deps = require "tools.deps"

module("tools.descriptor",package.seeall)

local search = require "tools.search"
local util   = require "tools.util"
local path   = require "tools.path"

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

  -- subpackage semantics (share the same source directory)
  local parent_dep = nil
  if spec.subpackage_of then
    assert(type(spec.subpackage_of) == "string","descriptor field subpackage_of is expected string got "..type(spec.subpackage_of))
    parent_dep = deps.parse_dep(spec.subpackage_of)
    if not parent_dep then
      return nil, "parse error processing dependency '"..spec.subpackage_of.."'"
    end
    -- AFAIK deps.parse_dep and search.make_query return compatible results so..
    local parent_spec_url = search.find_suitable_rock( parent_dep, config.SPEC_SERVERS, false)
    if not parent_spec_url then
      error("package '"..util.nameversion(spec).."' is dependent of '"..
        spec.subpackage_of.."' but it doesn't exist")
    end
    -- parent's descriptor loading
    local ok, tempfile = util.download(util.base_name(parent_spec_url), parent_spec_url, config.TMPDIR)
    if not ok then error("failed to download "..parent_spec_url) end
    local parent_spec = assert(load(tempfile))
    assert(parent_spec.name and parent_spec.version)
    assert(os.remove(tempfile))
    
    -- using some field from parent's descriptor
    if not spec.directory then
      spec.directory = parent_spec.directory or path.pathname(config.PRODAPP, util.nameversion(parent_spec))
    end
    if not spec.url and parent_spec.url then
      spec.url = parent_spec.url
    end
  end
  
  -- parsing dependencies  
  if spec.dependencies then
    for i = 1, #spec.dependencies do
       local parsed = deps.parse_dep(spec.dependencies[i])
       if not parsed then
          return nil, "parse error processing dependency '"..spec.dependencies[i].."'"
       end
       spec.dependencies[i] = parsed
    end
  else
    spec.dependencies = {}
  end
  
  if spec.subpackage_of then
    table.insert(spec.dependencies, 1, parent_dep)
  end

  if spec.build and (not spec.build.MacOS or not spec.build.Darwin) then
    spec.build.MacOS  = spec.build.MacOS or spec.build.Darwin
    spec.build.Darwin = spec.build.Darwin or spec.build.MacOS
  end
  return spec
end

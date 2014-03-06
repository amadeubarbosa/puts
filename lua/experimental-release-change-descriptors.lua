local fsep = "/"
local svnrepository = ...
local descreplace = {}
-- instruction: fill this table with log of make_release.lua script (tag: [script] [replace])
-- by hand (no handled by make_release.lua)
descreplace[ [[lua-5.2.2]] ]=[[lua-5.2.2.1]]
descreplace[ [[lua-bin-5.2.2]] ]=[[lua-bin-5.2.2.1]]
-- semi-automatic
descreplace[ [[openbus-busadmin-2.0.0compatLua52]] ]=[[openbus-busadmin-2.0.0.4]]
descreplace[ [[openbus-busservice-2.0.0compatLua52]] ]=[[openbus-busservice-2.0.0.4]]
descreplace[ [[luastruct-1.2compatLua52]] ]=[[luastruct-1.2.1]]
descreplace[ [[luasocket-2.0.2compatLua52]] ]=[[luasocket-2.0.2.1]]
descreplace[ [[luatuple-1.0betaCompatLua52]] ]=[[luatuple-1.0beta2]]
descreplace[ [[loop-3.0betaCompatLua52]] ]=[[loop-3.0beta2]]
descreplace[ [[luacothread-1.0betaCompatLua52]] ]=[[luacothread-1.0beta2]]
descreplace[ [[luaidl-0.6betaCompatLua52]] ]=[[luaidl-0.6beta2]]
descreplace[ [[oil-source-0.6betaCompatLua52]] ]=[[oil-source-0.6beta2]]
descreplace[ [[oil-0.6betaCompatLua52]] ]=[[oil-0.6beta2]]
descreplace[ [[luavararg-1.1compatLua52]] ]=[[luavararg-1.1.1]]
descreplace[ [[luafilesystem-1.4.2compatLua52]] ]=[[luafilesystem-1.4.2.1]]
descreplace[ [[luuid-1.0compatLua52]] ]=[[luuid-1.0.1]]
descreplace[ [[lce-2.0.0-1compatLua52]] ]=[[lce-2.0.1]]
descreplace[ [[scs-lua-1.2.3-1compatLua52]] ]=[[scs-lua-1.2.3.1]]
descreplace[ [[openbus-lua-2.0.0compatLua52]] ]=[[openbus-lua-2.0.0.2]]
descreplace[ [[openbus-idl2.0-2.0snapshot]] ]=[[openbus-idl2.0-2.0.2]]
descreplace[ [[lualdap-1.1.0CompatLua52]] ]=[[lualdap-1.1.0.1]]
descreplace[ [[openldap-2.4.11snapshot]] ]=[[openldap-2.4.11-oblibs1.3.2-1]]
-- end of editable table

-- instruction: fill this table with log of make_release.lua script (tag: [script] about new tags)
local url = {}
-- by hand (no handled by make_release.lua)
url[ [[/openbus/libs/lua/branches/5.2.2]] ]=[[/openbus/libs/lua/tags/5.2.2.1]]
-- semi-automatic
url[ [[/loop/trunk]] ]=[[/loop/tags/LOOP_3_0_beta2]]
url[ [[/oil/trunk]] ]=[[/oil/tags/OIL_0_6_beta2]]
url[ [[/luautils/lce/trunk]] ]=[[/luautils/lce/tags/02_00_01]]
url[ [[/scs/core/lua/branches/SCS_CORE_LUA_v1_02_03_2012_05_10]] ]=[[/scs/core/lua/tags/01_02_03_01]]
url[ [[/openbus/core/branches/02_00_00]] ]=[[/openbus/core/tags/02_00_00_04]]
url[ [[/openbus/idl/branches/02_00]] ]=[[/openbus/idl/tags/02_00_02]]
url[ [[/openbus/sdk/lua/branches/02_00_00]] ]=[[/openbus/sdk/lua/tags/02_00_00_02]]
url[ [[/openbus/libs/luafilesystem/branches/1.4.2/]] ]=[[/openbus/libs/luafilesystem/tags/1.4.2.1]]
url[ [[/openbus/libs/lualdap/branches/1.1.0]] ]=[[/openbus/libs/lualdap/tags/1.1.0.1]]
url[ [[/openbus/libs/luasocket/branches/2.0.2]] ]=[[/openbus/libs/luasocket/tags/2.0.2.1]]
url[ [[/openbus/libs/luuid/branches/1.0]] ]=[[/openbus/libs/luuid/tags/1.0.1]]
url[ [[/openbus/libs/struct/branches/1.2]] ]=[[/openbus/libs/struct/tags/1.2.1]]
url[ [[/openbus/libs/vararg/branches/1.1]] ]=[[/openbus/libs/vararg/tags/1.1.1]]
-- end of editable table

local function path(...)
  return table.concat({...}, fsep)
end

local function version(s)
  return s:match("%-(%d.*)")
end

local function name(s)
  return s:match("([%w%.%-%_]-)%-%d+.*$")
end

local function quote(s)
  return s:gsub("%.","%%."):gsub("%-","%%-")
end

-- create replacement table to use string.gsub
local deps_replacement = {}
do
  for old, new in pairs(descreplace) do 
    local oldname = name(old)
    local oldversion = version(old)
    deps_replacement[ oldname.." == "..oldversion ] = '"'..new..'"'
  end
  --[[DEBUG]] for k,v in pairs(deps_replacement) do
  --[[DEBUG]]   print("[debug] dep("..k..") = "..v)
  --[[DEBUG]] end
end

-- replace all the descriptors files
do
  for old, new in pairs(descreplace) do 
    print("[info] replacing "..old.." by "..new)
    filename = path(svnrepository,new..".desc")
    f = io.open(filename,"r")
    content = f:read("*a")
    f:close()
    --[[DEBUG]] print("[debug] old name = "..name(old).." version = "..version(old))
    --[[DEBUG]] print("[debug] new name = "..name(new).." version = "..version(new))
    replace,num = content:gsub('%"([%w%.%-%_]-%s*==.-)%"',deps_replacement)
    print("[info] "..num.." matches done about dependencies")
    --[[DEBUG]] print("[debug] ------------8<---------")
    --[[DEBUG]] print(replace)
    --[[DEBUG]] print("[debug] ------------>8---------")
    replace,num = replace:gsub('version.-%=%s*%p'..quote(version(old)).."%p", 'version = "'..version(new)..'"')
    print("[info] "..num.." matches done about version")
    --[[DEBUG]] print("[debug] ------------8<---------")
    --[[DEBUG]] print(replace)
    --[[DEBUG]] print("[debug] ------------>8---------")
    replace,num = replace:gsub('url.-%=%s*SVNREPURL.-(%/[%/%w%.%-%_]+)%p', function(oldurl) 
        if url[oldurl] then 
          return [[url = SVNREPURL.."]]..url[oldurl]..[["]] 
        end 
      end)
    print("[info] "..num.." matches done about url")
    --[[DEBUG]] print("[debug] ------------8<---------")
    --[[DEBUG]] print(replace)
    --[[DEBUG]] print("[debug] ------------>8---------")
    f = io.open(filename,"w")
    f:write(replace)
    f:close()
  end
end

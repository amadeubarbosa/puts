local string = string
local table  = table
local unpack = unpack
--VERBOSE local print,io  = print,io

-- split dummy implementation for Lua string module
module("string.split")

string.split = function(str,sep,non_white)
  non_white = non_white or false
  local it  = string.gmatch(str,sep)
  local ret = {}
  local elem = it()
  while (elem) do
    if non_white then elem = elem:gsub("%s","") end
    table.insert(ret,elem)
    elem = it()
  end
  return unpack(ret)
end
return string
--VERBOSE test = "!@#$%*()^~;/.,<][{}\\|a=>:b=>h\t\t\t\t\t\t=>x"
--VERBOSE print(test:split("[^=>]*"))
--VERBOSE print(test:split("[^=>]*",true))
--VERBOSE
--VERBOSE p = io.popen("ldd /usr/bin/awk","r")
--VERBOSE test = p:read("*a")
--VERBOSE p:close()
--VERBOSE print(test:split("[^=>]*",true))


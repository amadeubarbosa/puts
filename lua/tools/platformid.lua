module("tools.platformid", package.seeall)

-- Table of the tecmake commands to determine that identify the platform
local Identity = {}
-- Metatable that will execute the system commands and save the results
setmetatable(Identity,{
  __call = function(self,force) 
    for id,command in pairs(self.commands) do
      if not self[id] or force then
        self[id] = io.popen(command):read("*l")
      end
    end
  end,
})
-- Basic commands used by tecmake
Identity.commands = {
  TEC_SYSNAME = "uname -s",
  TEC_SYSVERSION = "uname -r|cut -f1 -d.",
  TEC_SYSMINOR = "uname -r|cut -f2 -d.",
  TEC_SYSARCH = "uname -m",
  TEC_UNAME = nil, -- automatically infered
}
-- Call that causes the execution of Identity.commands and 
-- saves the results directly on Identity
Identity()

-- Some fixes made by Tecmake
local sysname = Identity.TEC_SYSNAME
if sysname:match("SunOS") or sysname:match("IRIX") or sysname:match("Darwin") or sysname:match("MacOS") then
  Identity.commands.TEC_SYSARCH = "uname -p"
elseif sysname:match("FreeBSD") then
  Identity.commands.TEC_SYSMINOR = "uname -r|cut -f2 -d.|cut -f1 -d-"
elseif sysname:match("AIX") then
  Identity.commands.TEC_SYSVERSION = "uname -v"
  Identity.commands.TEC_SYSMINOR = "uname -r"
  Identity.commands.TEC_SYSARCH = "ppc"
end
-- Call that forces to execute the Identity.commands again 
-- to apply fixes above
Identity(true)

-- Another CPU identification fixes
local sysarch = Identity.TEC_SYSARCH
if sysarch:match("i[36]86") then
  Identity.TEC_SYSARCH = "x86"
elseif sysarch:match("powerpc") then
  Identity.TEC_SYSARCH = "ppc"
elseif sysarch:match("x86_64") then
  Identity.TEC_SYSARCH = "x64"
end

Identity.TEC_SYSRELEASE = Identity.TEC_SYSVERSION.."."..Identity.TEC_SYSMINOR
Identity.TEC_UNAME = Identity.TEC_SYSNAME..Identity.TEC_SYSVERSION..Identity.TEC_SYSMINOR

-- Another compiler version identification fixes
local gccversion = io.popen("gcc -dumpversion|cut -f1 -d."):read("*l")
if gccversion then
  if Identity.TEC_UNAME == "Linux24" then
    if gccversion == "3" then
      Identity.TEC_UNAME = Identity.TEC_UNAME.."g3"
    end
  elseif Identity.TEC_UNAME == "Linux26" then
    if gccversion == "4" then
      Identity.TEC_UNAME = Identity.TEC_UNAME.."g4"
    end
  end
end

-- Yet another CPU identification fixes
if Identity.TEC_SYSNAME == "Linux" and Identity.TEC_SYSARCH == "ppc" then
  Identity.TEC_UNAME = Identity.TEC_UNAME.."ppc"
elseif 
  (Identity.TEC_SYSNAME == "SunOS" or Identity.TEC_SYSNAME == "Darwin" or Identity.TEC_SYSNAME == "MacOS")
  and Identity.TEC_SYSARCH == "x86" then
  Identity.TEC_UNAME = Identity.TEC_UNAME.."x86"
end

if Identity.TEC_SYSARCH == "x64" then
  Identity.TEC_UNAME = Identity.TEC_UNAME.."_64"
elseif Identity.TEC_SYSARCH == "ia64" then
  Identity.TEC_UNAME = Identity.TEC_UNAME.."_ia64"
end

return Identity
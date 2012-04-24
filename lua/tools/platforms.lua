local table  = table
local os     = os
local ipairs = ipairs
local print,io  = print,io
local setmetatable = setmetatable 
local id = require "tools.platformid"

module("tools.platforms")

-- PROBLEMA: como identificar corretamente quais diretórios padrões são usados
-- pelo link editor em tempo de carga? se a LD_LBIRARY_PATH estiver vazia
-- esses diretórios padrões serão usados na busca por símbolos, mas aí nosso
-- search_ldlibpath não saberá identificar que não é uma falta de lib!
-- REFLEXAO: nossa intenção com search_ldlibpath é reproduzir o mecanismo por
-- plataforma de busca de bibliotecas dependentes! precisamos mesmo?

platforms = {
  id = id,
  pipe_stderr = " 2>/dev/null",
  dylibext = "so",
  cmd = { install = "cp -rf ", make = "make ", mkdir = "mkdir -p ", rm = "rm -rf ", ls = "ls ",
    gunzip = "gunzip -c ", tar = "tar ", bunzip2 = "bunzip2 -c ", unzip = "unzip ", pwd = "pwd ",
    test = "test "
   },
  exec = function(cmd)
    local pipe = io.popen(cmd,"r")
    local stdout = pipe:read("*a")
    pipe:close()
    -- BETTER: 'if stdout:len() == 0 then return nil end' useful with assert!
    return stdout
  end,
  search_ldlibpath = function(self,file,dirs,libpath_var)
    local dirs = dirs or "/usr/lib"
    local libpath_var = libpath_var or "LD_LIBRARY_PATH"
    local ld_var = os.getenv(libpath_var)
    if ld_var then dirs = ld_var .. ":" .. dirs end
    local realpath = false
    for _,dir in ipairs({dirs:split("[^:]+")})
    do
      if io.open(dir .."/"..file, "r") then
        realpath = dir .."/"..file
        break
      else
        -- if file is a regular expression we must check filenames on dir 
        realpath = self.exec("ls ".. dir .."/".. file .. self.pipe_stderr)
        if realpath == "" then 
          realpath = false 
        else 
          break 
        end
      end
    end
    return realpath
  end,
}
platforms.Linux = {
  pipe_stderr = platforms.pipe_stderr,
  dylibext = platforms.dylibext,
  cmd = { install = "cp -L -Rf ", make = "make ", mkdir = "mkdir -p ", rm = "rm -rf ", ls = "ls " },
  exec = platforms.exec, 
  unknown_symbols = function(self,file) 
    return self.exec("nm -f sysv -u -D ".. file .. " |awk -F'|' '/UND/ {print $1}'"):gsub("^%d*$","")
  end,
  search_ldlibpath = function(self,file,dir)
    if dir and not dir:find(":$") then dir = dir:gsub("$",":")
                                  else dir = "" end
    local libpath = dir.."/lib:/usr/lib:/usr/local/lib:/lib32:/lib64:/usr/lib32:/usr/lib64"
    return platforms.search_ldlibpath(self,file,libpath)
  end,
  -- sample ldd output on Linux:
  -- linux-gate.so.1 =>  (0xffffe000)
  -- libcrypto.so.0.9.9 => not found
  -- libdl.so.2 => /lib/tls/i686/cmov/libdl.so.2 (0xb7ebb000)
  missing_libraries = function(self,file)
    if os.execute("test -f ".. file) ~= 0 then
      return false
    end
    -- testing if it's a script
    if self.exec("file ".. file):match("text") then
      return false
    end
    if not self.exec("file ".. file):match("ELF") and not file:match("%.a$") then
      return false, "it isn't a ELF file"
    end
    local str = self.exec("ldd ".. file)
    local miss = {}
    local f = str:gmatch("[^\n]+")
    local line = f()
    while (line) do
      local lib , dep = line:split("[^=>]+",true)
      if lib then lib = lib:gsub("%b()","") end
      if dep then 
        dep = dep:gsub("[()]","")
        if dep:find("notfound") then
          table.insert(miss,lib)
        end
      end
      line = f()
    end
    if #miss == 0 then
      return false
    else
      return miss
    end
  end,
}
setmetatable(platforms.Linux.cmd, { __index = platforms.cmd })
platforms.SunOS = {
  pipe_stderr = platforms.pipe_stderr,
  dylibext = platforms.dylibext,
  exec = platforms.exec,
  cmd = { tar = "gtar " },
  unknown_symbols = function(self,file) 
    return self.exec("nm -f sysv -u ".. file .. " |awk -F'|' '/UNDEF/ {print $8}'"):gsub("^%d*$","") 
  end,
  search_ldlibpath = function(self,file,dir)
    if dir and not dir:find(":$") then dir = dir:gsub("$",":")
                                  else dir = "" end
    local libpath = dir.."/lib:/usr/lib:/usr/sfw/lib:/usr/local/lib"
    return platforms.search_ldlibpath(self,file,libpath) 
  end,
  -- sample ldd output on Solaris:
  --  libcrypto.so.0.9.9 =>    (file not found)
  --  libgcc_s.so.1 =>         (file not found)
  --  libsocket.so.1 =>        /lib/libsocket.so.1
  --  libnsl.so.1 =>   /lib/libnsl.so.1
  --  libdl.so.1 =>    /lib/libdl.so.1
  --  libc.so.1 =>     /lib/libc.so.1
  missing_libraries = platforms.Linux.missing_libraries
}
setmetatable(platforms.SunOS.cmd, { __index = platforms.cmd })
platforms.IRIX = {
  pipe_stderr = platforms.pipe_stderr,
  dylibext = platforms.dylibext,
  exec = platforms.exec,
  cmd = { install = "cp -Rf ", make = "gmake ", mkdir = "mkdir -p ", rm = "rm -rf ", ls = "ls "},
  unknown_symbols = function(self,file) 
    return self.exec("nm -u ".. file .. " |awk -F'|' '/UNDEF/ {print $8}'"):gsub("^%d*$","") 
  end,
  search_ldlibpath = function(self,file,dir)
    if dir and not dir:find(":$") then dir = dir:gsub("$",":")
                                  else dir = "" end
    local libpath = dir.."/usr/lib:/usr/lib32:/usr/lib64:/usr/freeware/lib32"
    return platforms.search_ldlibpath(self,file,libpath)
  end,
  missing_libraries = function(self,file)
    if os.execute("test -f ".. file) ~= 0 then
      return false
    end
    -- testing if it's a script
    if self.exec("file ".. file):match("text") then
      return false
    end
    if not self.exec("file ".. file):match("ELF") and not file:match("%.a$") then
      return false, "it isn't a ELF file"
    end
    local str = self.exec("elfdump -Dl ".. file)
    local miss = {}
    local f = str:gmatch("[^\n]*")
    local line = f()
    while (line) do
      arg = {line:split("[^%s]+",true)}
      if arg[8] and not self:search_ldlibpath(arg[8]) then
        table.insert(miss,arg[8])
      end
      line = f()
    end
    if #miss == 0 then
      return false
    else
      return miss
    end
  end,
}
setmetatable(platforms.IRIX.cmd, { __index = platforms.cmd })
platforms.Darwin = {
  pipe_stderr = platforms.pipe_stderr,
  dylibext = "dylib",
  exec = platforms.exec,
  cmd = platforms.Linux.cmd,
  unknown_symbols = function(self,file) 
    return self.exec("nm -u ".. file) 
  end,
  search_ldlibpath = function(self,file,dir)
    if dir and not dir:find(":$") then dir = dir:gsub("$",":")
                                  else dir = "" end
    local libpath = dir.."/usr/lib"
    return platforms.search_ldlibpath(self,file,libpath,"DYLD_LIBRARY_PATH")
  end,
  missing_libraries = function(self,file)
    if os.execute("test -f ".. file) ~= 0 then
      return false
    end
    -- testing if it's a script
    if self.exec("file ".. file):match("text") then
      return false
    end
    if not self.exec("file ".. file):match("Mach%-O") and not file:match("%.a$") then
      return false, "isn't a Mach-O file"
    end
    local str = self.exec("otool -L ".. file)
    local miss = {}
    local f = str:gmatch("[^\n]*")
    local line = f()
    while (line) do
      line = line:gsub(".*:","")
      file = line:split("[^%s]+",true)
      if file then
        realpath = self.exec("find ".. file ..self.pipe_stderr)
        if realpath == "" then
          local basedir,basename = file:gmatch("(.*%/+)(.+)")()
          -- basename can be nil when linked using RPath
          -- in this case we should try the filename
          if not self:search_ldlibpath(basename or file) then
            table.insert(miss,basename or file)
          end
        end
      end
      line = f()
    end
    if #miss == 0 then
      return false
    else
      return miss
    end
  end,
}
platforms.MacOS = platforms.Darwin
--~ platforms.Windows = {
  --~ pipe_stderr = " >STDERR.txt",
  --~ dylibext = "dll",
  --~ cmd = {
    --~ install = "xcopy /E /H ", -- xcopy don't copy orig dir also, only subdirs
    --~ make = "nmake ",
    --~ mkdir = "mkdir ",
    --~ ls = "dir ",
  --~ },
  --~ exec = platforms.exec, -- Lua provides pipe semantic on Windows too!
--~ }

return platforms

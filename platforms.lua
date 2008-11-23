local table  = table
local os     = os
local ipairs = ipairs
local print,io  = print,io

module("platforms")

platforms = {
	dylibext = "so",
	cmd = { install = "cp -Rf ", make = "make ", mkdir = "mkdir -p ", rm = "rm -rf ", ls = "ls " },
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
			realpath = self.exec("find ".. dir .." -name ".. file)
			if realpath == "" then realpath = false else break end
		end
		return realpath
	end,
}
platforms.Linux = {
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
		return platforms:search_ldlibpath(file,libpath)
	end,
	-- sample ldd output on Linux:
	-- 	linux-gate.so.1 =>  (0xffffe000)
	--	libcrypto.so.0.9.9 => not found
	--	libdl.so.2 => /lib/tls/i686/cmov/libdl.so.2 (0xb7ebb000)
	missing_libraries = function(self,file)
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
platforms.SunOS = {
	dylibext = platforms.dylibext,
	exec = platforms.exec,
	cmd = platforms.cmd,
	unknown_symbols = function(self,file) 
		return self.exec("nm -f sysv -u ".. file .. " |awk -F'|' '/UNDEF/ {print $8}'"):gsub("^%d*$","") 
	end,
	search_ldlibpath = function(self,file,dir)
		if dir and not dir:find(":$") then dir = dir:gsub("$",":")
		                              else dir = "" end
		local libpath = dir.."/lib:/usr/lib:/usr/sfw/lib:/usr/local/lib"
		return platforms:search_ldlibpath(file,libpath) 
	end,
	-- sample ldd output on Solaris:
	--	libcrypto.so.0.9.9 =>    (file not found)
	--	libgcc_s.so.1 =>         (file not found)
	--	libsocket.so.1 =>        /lib/libsocket.so.1
	--	libnsl.so.1 =>   /lib/libnsl.so.1
	--	libdl.so.1 =>    /lib/libdl.so.1
	--	libc.so.1 =>     /lib/libc.so.1
	missing_libraries = platforms.Linux.missing_libraries
}
platforms.IRIX = {
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
		return platforms:search_ldlibpath(file,libpath)
	end,
	missing_libraries = function(self,file)
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
platforms.Darwin = {
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
		return platforms:search_ldlibpath(file,libpath,"DYLD_LIBRARY_PATH")
	end,
	missing_libraries = function(self,file)
		local str = self.exec("otool -L ".. file)
		local miss = {}
		local f = str:gmatch("[^\n]*")
		local line = f()
		while (line) do
			line = line:gsub(".*:","")
			file = line:split("[^%s]+",true)
			if file then
				realpath = self.exec("find ".. file)
				if realpath == "" then
					local basedir,basename = file:gmatch("(.*%/+)(.+)")()
					if not self:search_ldlibpath(basename) then
						table.insert(miss,basename)
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
--~ platforms.Windows = {
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

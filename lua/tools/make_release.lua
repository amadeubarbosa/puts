local config    = require "tools.config"
local util      = require "tools.util"
local descriptor = require "tools.descriptor"
local deps      = require "tools.deps"
local platforms = require "tools.platforms"
local myplat    = platforms[config.TEC_SYSNAME]
local manifest  = require "tools.manifest"
local search    = require "tools.search"

--[[ debug functions
function trace (event, line)
  local info = debug.getinfo(2)
  local funcname = info.name or ""
  local line = info.currentline or line
  if line > 0 then
    if event == "return" then
      print("\t\t[return]", funcname..":"..(line or ""))
    else
      print("\t\t[call]",(info.short_src or "") ..":".. funcname .. ":" .. (line or ""))
    end
  end
end

debug.sethook(trace, "c")
--]]
local timestamp = os.date("%Y%m%d_%H%M%S")

print_original = print
local filelog = io.open("release-"..timestamp..".log","w")
print=function(...)
  filelog:write(table.concat({...}," ").."\n")
  print_original(...)
end

for key,_ in pairs(util.log._levels) do
  util.log._levels[key] = false
end

local function is_snapshot(version)
  assert(type(version) == "string")

  if version:match("snapshot") or version:lower():match("compatlua52") then
    return true
  else
    return false
  end
end

myplat.exec(myplat.cmd.mkdir..config.TMPDIR)
 
SPEC_SERVERS = { 
--"http://www.tecgraf.puc-rio.br/ftp_pub/openbus/repository/specs",
  "file:///Users/amadeu/Work/Tecgraf/SVN/openbus/puts/repository",
}

DEPENDENCY_LIST = {}
REPLACEMENT = { --[[ from = "to" ]]}
BUILDTREE = config.TMPDIR

tag_creation = function(pkg, specfile, ...)
  if pkg and type(pkg) == "table" then
    specfile =  config.SPEC_SERVERS[1].."/"..util.nameversion(pkg)..".desc"
  else
    pkg = temporary_load(assert(specfile))
  end

  assert(pkg.name)
  assert(pkg.version)
  
  if is_snapshot(pkg.version) then
    local function svn_retrieve_last_change_revision(url)
      assert(type(url) == "string")
      local svn_info = io.popen("svn info "..url.." 2>/dev/null","r")
      local revision = svn_info:read("*a"):match("Last Changed Rev: (%d+)")
      svn_info:close()
      
      return (revision and tonumber(revision)) or -1
    end
    local function svn_list_similar_names(url, name)
      local patt = "^"..name:gsub("%-","%%-").."%-(%d.*)%.desc$"
      url = url:gsub("%/+$","")
      local svn_list = io.popen("svn list "..url.." 2>/dev/null","r")
      while true do
        local item = svn_list:read("*l")
        if not item or item == "" then
          break
        end
        if patt then
          local version = item:match(patt)
          if version then
            print("  "..version, "("..url.."/"..item..")")
          end
        end
      end
      svn_list:close()
    end
    local function svn_list_with_last_change(url,subdir,sorted)
      if subdir then
        subdir = "/"..subdir
      end
      local last_changes = sorted or {}
      local svn_list = io.popen("svn list "..url.." 2>/dev/null","r")
      while true do
        local tag = svn_list:read("*l")
        if not tag or tag == "" then
          break
        end
        tag = tag:gsub("%/$","")
        local complete_url = url.."/"..tag..(subdir or "")
        local last_change = svn_retrieve_last_change_revision(complete_url)
        if last_change > 0 then -- is valid
          local t = {complete_url,tonumber(last_change)}
          table.insert(last_changes,t)
          print("  "..table.concat(t,"\t"))
        end
      end
      svn_list:close()
      table.sort(last_changes,function(t1,t2)
        if t1[2] == t2[2] then
          return t1[1] > t2[1] -- string comparison
        else
          return t1[2] > t2[2] -- number comparison
        end
      end)
      return last_changes
    end

    local function giveme(pkg)
      assert(pkg.version)
      local sugg_newversion = ""
      if pkg.url then
        local url = pkg.url
        local is_under_subversion = false
        if url:match("^svn") then
          is_under_subversion = true
        end
        url = url:gsub("svn%+","")
        local revision = -1
        if is_under_subversion then
          revision = svn_retrieve_last_change_revision(url)
        end
        print("[info]","current url is:",url,revision)
        local sugg = {}
        -- se for trunk vou precisar criar o branch (caso n�o exista) e a tag
        if url:match("/trunk") then
          local subdir = url:match("/trunk/(.*)")
          local parent = url:gsub("/trunk.*","")
          print("[info]","svn list of branches:")
          svn_list_with_last_change(parent.."/branches",subdir,sugg)
          print("[info]","svn list of tags:")
          svn_list_with_last_change(parent.."/tags",subdir,sugg)
        end
        -- investigando qual vai ser a nova tag (old_version + 1)
        if url:match("/branches") then
          local subdir = url:match("/branches/.-/(.*)")
          local parent = url:gsub("/branches.*","")
          print("[info]","svn list of tags:")
          svn_list_with_last_change(parent.."/tags",subdir,sugg)
        end
        if url:match("/tags") then
          print("[warning]","svn tag is already the newest possible:", url)
        end
        
        if #sugg > 0 and sugg[1][2] and sugg[1][2] > revision then 
          --table.foreach(sugg, function(i,t) print(i,t[1],t[2]) end)
          print("[suggestion]",sugg[1][1])
        end

        print("[question]","inform a new url or suggestion or press return to skip")
        local newurl = io.read("*l")

        if newurl ~= "" then
          if newurl:lower() == "suggestion" then
            newurl = sugg[1][1]
          end
          if os.execute("svn info ".. newurl .. " 2>/dev/null >/dev/null") ~= 0 then
            print("[script]","svn cp "..url.." "..newurl)
            if newurl:match("branches") then
              print("[question]","would you like to create a tag for this branch? inform a new tag url or press return to skip")
              local newtag = io.read("*l")
              if newtag ~= "" then
                local version_mark = newtag:match("/(.-)$")
                local m = version_mark:gmatch("(%d%d)%_?")
                repeat
                  local num = m()
                  if num ~= nil then
                    sugg_newversion = sugg_newversion..tonumber(num).."."
                  else
                    sugg_newversion = sugg_newversion:sub(1,#sugg_newversion-1)
                  end
                until (num == nil)

                print("[script]","svn cp "..newurl.." "..newtag)
              end
            end
          else
            print("[warning]",newurl.." already exists!")
          end
        end
      end
      if is_snapshot(pkg.version) then
        local repository = config.SPEC_SERVERS[1].."/"
        if repository:match("^file") then
          repository = repository:gsub("file://","")
        end
        print("[info]","current version is:",pkg.version)
        print("[info]","versions stored in repositories:")
        svn_list_similar_names(repository, pkg.name)

        if #sugg_newversion > 0 then 
          print("[suggestion]",sugg_newversion)
        end

        print("[question]","inform a new version or suggestion or press return to skip")
        local newversion = io.read("*l")
        if newversion ~= "" then
          if newversion:lower() == "suggestion" then
            newversion = sugg_newversion
          end
          local newnameversion = pkg.name.."-"..newversion
          if os.execute("svn info "..repository..newnameversion..".desc 2>/dev/null >/dev/null") ~= 0 then
            print("[script]","svn cp "..repository..util.nameversion(pkg)..".desc "..
                                      repository..newnameversion..".desc")
            REPLACEMENT[util.nameversion(pkg)] = newnameversion
            print("[script] [replace]",util.nameversion(pkg),newnameversion)
          else
            diff_cmd = "diff -up "..repository..util.nameversion(pkg)..".desc "..repository..newnameversion..".desc"
            diff_out = io.popen(diff_cmd,"r"):read("*a")
            print("[debug]",diff_cmd)
            print(diff_out)
            print("[debug] ---------------------------------------------------")
            print("[question]","are you sure to use "..newversion.."? yes or no")
            local ok
            repeat
              ok = io.read("*l")
              if ok ~= "" and ok == "no" then
                print("[restart]","trying again for the package "..util.nameversion(pkg))
                giveme(pkg)
              end
            until (ok and ok ~= "" and (ok == "yes" or ok == "no"))
            if ok == "yes" then
              print("[script] [replace]",util.nameversion(pkg),newnameversion)
            end
          end
        end
      else
        print("[warning]","package version is already the newest possible:", pkg.version)
      end
    end
    print("--------------------------------------------------------------------")
    print("[info]","processing the package", util.nameversion(pkg))
    giveme(pkg)
  end
  

  if not manifest.is_installed(MANIFEST, pkg.name, pkg.version) then
    assert(deps.fulfill_dependencies(pkg, SPEC_SERVERS, BUILDTREE, MANIFEST, tag_creation, nil, DEPENDENCY_LIST))
    assert(manifest.update_manifest(pkg, BUILDTREE, MANIFEST))
  end
  
  return true, pkg
end

function temporary_load(specfile)
  local ok, tempfile = util.download(util.base_name(specfile),specfile,BUILDTREE)
  if not ok then
    io.stderr:write("[error] package doesn't exist\n")
    io.stderr:flush()
    os.exit(1)
  end
  local desc = assert(descriptor.load(tempfile))
  assert(desc.name and desc.version)
  assert(os.remove(tempfile))
  return desc
end

--------------
-- Main
--------------
if not arg[1] or not arg[2] then
  print("Usage: "..arg[0].." <nome do pacote com vers�o> <diret�rio vazio que conter� o manifesto>")
  os.exit(1)
end

if arg[1] then
  if not arg[1]:find("^/") then
    specfile = path.pathname(SPEC_SERVERS[1],arg[1]..".desc")
  else
    specfile = arg[1]
  end

  if arg[2] then
    BUILDTREE = arg[2]
    if os.execute("test -d "..BUILDTREE) == 0 then
      MANIFEST = manifest.load(BUILDTREE)
    else
      myplat.exec(myplat.cmd.mkdir..BUILDTREE)
    end
  end

  if not MANIFEST then
    _, MANIFEST = assert(manifest.rebuild_manifest(BUILDTREE))
  end

  print("[timestamp]",os.time())
  assert(tag_creation(nil,specfile,nil))
  print("[timestamp]",os.time())

  -- dump all dependencies
  --table.foreach(DEPENDENCY_LIST, print)

  -- dump all replacement
  print("[debug]","dependency replacement list:")
  table.foreach(REPLACEMENT, print)
  print("[debug]","end of dependency replacement")

else
  io.stderr:write("[error] nothing to do! Usage: <package id> <buildtree>\n")
  io.stderr:flush()
  os.exit(1)
end

myplat.exec(myplat.cmd.rm..config.TMPDIR)

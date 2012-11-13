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

print_original = print
local filelog = io.open("release.log","w")
print=function(...)
  filelog:write(table.concat({...}," ").."\n")
  print_original(...)
end

for key,_ in pairs(util.log._levels) do
  util.log._levels[key] = false
end

myplat.exec(myplat.cmd.mkdir..config.TMPDIR)
 
SPEC_SERVERS = { 
--"http://www.tecgraf.puc-rio.br/ftp_pub/openbus/repository/specs",
  "file:///Users/amadeu/Work/Tecgraf/SVN/openbus/puts/repository",
}

DEPENDENCY_LIST = {}
REPLACEMENT = { --[[ from = "to" ]]}

_, MANIFEST = assert(manifest.rebuild_manifest(config.TMPDIR))

tag_creation = function(pkg, specfile, ...)
  if pkg and type(pkg) == "table" then
    specfile =  config.SPEC_SERVERS[1].."/"..util.nameversion(pkg)..".desc"
  else
    pkg = temporary_load(assert(specfile))
  end

  assert(pkg.name)
  assert(pkg.version)
  
  if pkg.version:match("snapshot") then
    --guess
    local function guess(pkg)
      if pkg.url then
        local protocol = util.split_url(pkg.url)
        if protocol:match("^svn") then
          if pkg.url:match("branches") then
            local branch = pkg.url:match("branches/(.+)")
            branch = branch:match("(.-)/") or branch
            --[[example:
            SCS_CORE_LUA_v1_02_02_2011_07_08
            |----------|                     = project id
                         v                   = mandatory character
                         |------|            = project version (can be composed by one, two, three or more numbers)
                                  |--------| = release date
            ]]
            tecgraf_version_patt = ".-v(%d)_(.-)_(%d%d%d%d)_(%d%d)_(%d%d)"
            function is_year(num)
              return num and tonumber(num) and ((num/1000) > 1)
            end
            --[[
            100+ultimo
            1000+penultimo
            10000+antepenultimo ...
            ]]
            version_num = {branch:match(tecgraf_version_patt)}
            
            print("[info]"," parse versions",branch:match(".-v([_%d]+)"),"#"..#version_num, unpack(version_num))
            local year = version_num[#version_num-2]
            print("[info]"," year check",year,is_year(year))
            
            return "branches", branch
          elseif pkg.url:match("tags") then
            return "tags"
          elseif pkg.url:match("trunk") then
            return "trunk"
          end
        else
          io.stderr:write("cannot create a tag of a package hosted in a "..protocol.." service\n")
          return nil
        end
      end
      return nil
    end

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
            print(version, "("..url.."/"..item..")")
          end
        end
      end
      svn_list:close()
    end
    local function svn_list_with_last_change(url,subdir,sorted)
      local last_changes = sorted or {}
      local svn_list = io.popen("svn list "..url.." 2>/dev/null","r")
      while true do
        local tag = svn_list:read("*l")
        if not tag or tag == "" then
          break
        end
        tag = tag:gsub("%/$","")
        if subdir then
          subdir = "/"..subdir
        end
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
        -- se for trunk vou precisar criar o branch (caso não exista) e a tag
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
                print("[script]","svn cp "..newurl.." "..newtag)
              end
            end
          else
            print("[warning]",newurl.." already exists!")
          end
        end
      end
      if pkg.version:match("snapshot") then
        local repository = config.SPEC_SERVERS[1].."/"
        if repository:match("^file") then
          repository = repository:gsub("file://","")
        end
        print("[info]","current version is:",pkg.version)
        print("[info]","versions stored in repositories:")
        print("[debug]",pkg.name)
        svn_list_similar_names(repository, pkg.name)
        print("[question]","inform a new version or press return to skip")
        local newversion = io.read("*l")
        if newversion ~= "" then
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
            print("[debug]")
            print("[question]","are you sure to use "..newversion.."? yes or no")
            repeat
              local ok = io.read("*l")
              if ok ~= "" and ok == "no" then
                print("[restart]","trying again for the package "..util.nameversion(pkg))
                giveme(pkg)
              end
            until (ok and ok ~= "" and (ok == "yes" or ok == "no"))
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
    assert(deps.fulfill_dependencies(pkg, SPEC_SERVERS, config.TMPDIR, MANIFEST, tag_creation, nil, DEPENDENCY_LIST))
    assert(manifest.update_manifest(pkg, config.TMPDIR, MANIFEST))
  end
  
  return true, pkg
end

function temporary_load(specfile)
  local ok, tempfile = util.download(util.base_name(specfile),specfile,config.TMPDIR)
  assert(ok)
  local desc = assert(descriptor.load(tempfile))
  assert(desc.name and desc.version)
  assert(os.remove(tempfile))
  return desc
end

if not arg[1]:find("^/") then
  specfile = path.pathname(SPEC_SERVERS[1],arg[1]..".desc")
else
  specfile = arg[1]
end

assert(tag_creation(nil,specfile,nil))

-- dump all dependencies
--table.foreach(DEPENDENCY_LIST, print)

-- dump all replacement
print("[debug]","dependency replacement list:")
table.foreach(REPLACEMENT, print)
print("[debug]","end of dependency replacement")

myplat.exec(myplat.cmd.rm..config.TMPDIR)
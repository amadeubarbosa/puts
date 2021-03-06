--- Default configuration used by package assistants.
-- Using the following directories structure:
-- <ul>
-- <li> puts/build/{a,b,c} = all source code of software being compiled </li>
-- <li> puts/source        = (deprecated) main source code of openbus project (1.4.x and 1.5.x) </li>
-- <li> puts/install       = directory similar to /usr of an unix machine, some
--                           artifacts will be copied to here after compilation
--                           (described on install_files table on descriptors) <br />
-- </ul>
-- The most important variables configured are documented as fields.
-- @class table
-- @name tools.config
-- @field TEC_UNAME Tecmake way to recognize the specific system identifier
-- @field TEC_SYSNAME Tecmake way to recognize the generic system identifier
-- @field BASEDIR Base directory to place all stuff (external libs, source codes, metadatas, etc)
-- @field PRODAPP <b>[Advanced]</b> Where the external packages will be extracted
-- @field SVNURL <b>[Advanced]</b> Location of the source code to be compiled
-- @field SVNDIR <b>[Advanced]</b> (Depreacted) Where the source code will be checked out
-- @field DEPLOYDIR <b>[Advanced]</b> (Deprecated) Where are the 'puts' related configurations
-- @field INSTALL.TOP <b>[Advanced]</b> Where the binaries, libraries, includes and others will be stored after the compilation

-- Tecmake compatibility variables
-- You could (in a very special case) redefine this to work with the compile.lua

local id = require "tools.platformid"

module("tools.config", package.seeall)

SPEC_SERVERS = SPEC_SERVERS or {
  "https://git.tecgraf.puc-rio.br/openbus/puts-repository/raw/master", 
}

TEC_UNAME = TEC_UNAME or os.getenv("TEC_UNAME") or id.TEC_UNAME
assert(TEC_UNAME, "ERROR: TEC_UNAME env var not defined")
TEC_SYSNAME = TEC_SYSNAME or os.getenv("TEC_SYSNAME") or id.TEC_SYSNAME
assert(TEC_SYSNAME, "ERROR: TEC_SYSNAME env var not defined")

-- Base variables to compile and install time
BASEDIR = BASEDIR or os.getenv("WORKSPACE") or os.getenv("HOME") .."/puts"
assert(BASEDIR or os.getenv("HOME"), "ERROR: HOME env var not defined")

PRODAPP = PRODAPP or BASEDIR .."/build"

GITREPURL = GITREPURL or "git+https://git.tecgraf.puc-rio.br" 
SVNREPURL = SVNREPURL or "svn+https://subversion.tecgraf.puc-rio.br/engdist"
SVNURL = SVNURL or SVNREPURL .. "/openbus/trunk"
SVNDIR = SVNDIR or BASEDIR .."/source"
DEPLOYDIR = DEPLOYDIR or SVNDIR .."/specs"
DOWNLOADDIR = DOWNLOADDIR or BASEDIR .."/packs"
PKGDIR = PKGDIR or DOWNLOADDIR .."/metadata/".. TEC_UNAME
PKGPREFIX = PKGPREFIX or "openbus-"

INSTALL = INSTALL or {}
INSTALL.TOP = INSTALL.TOP or BASEDIR .."/install"
INSTALL.BIN = INSTALL.BIN or INSTALL.TOP .."/bin"
INSTALL.LIB = INSTALL.LIB or INSTALL.TOP .."/lib"
INSTALL.INC = INSTALL.INC or INSTALL.TOP .."/include"

function giveRandomEmptyDir()
  repeat
    tmp = os.tmpname()
    ok, err = os.remove(tmp)
  until (ok)

  return tmp
end

TMPDIR = TMPDIR or giveRandomEmptyDir().."_putsbuilding"

-- Supported arch to makepack
SUPPORTED_ARCH = SUPPORTED_ARCH or {
  "Linux24g3", 
  "Linux24g3_64", 
  "Linux26", 
  "Linux26_64", 
  "Linux26g4", 
  "Linux26g4_64", 
  "Linux26_ia64", 
  --"SunOS58",
  "SunOS510",
  "SunOS510x86", 
  "Darwin811x86",
  "Darwin96x86",
  "MacOS107",
}

-- Given a way to change platform specific variables.
-- Useful for the makepack script that needs create packages for many platforms
-- from a different TEC_UNAME machine.
function changePlatform(arch)
  local pkgdir = PKGDIR:gsub(TEC_UNAME,arch)
  local installbin = INSTALL.BIN:gsub(TEC_UNAME,arch)
  local installlib = INSTALL.LIB:gsub(TEC_UNAME,arch)
  return pkgdir, installbin, installlib
end

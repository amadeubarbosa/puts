--- Default configuration used by package assistants.
-- Using the following directories structure.
-- <ul>
-- <li> openbus/lib/{a,b,c} = lua libs like lfs,luasocket,oil04,latt </li>
-- <li> openbus/lib/{d,e,f}     = base softwares like openldap,openssl </li>
-- <li> openbus/trunk          = svn export or checkout </li>
-- <li> openbus/install        = install dir to use install_files table to copy here like: <br />
-- <code> cp -r -Lf {a,b,c,d,e,f}/lib/$TEC_UNAME/* openbus/install/libpath/$TEC_UNAME/ </code></li>
-- </ul>
-- The most important variables configured are documented as fields.
-- @class table
-- @name tools.config
-- @field TEC_UNAME Tecmake way to recognize the specific system identifier
-- @field TEC_SYSNAME Tecmake way to recognize the generic system identifier
-- @field BASEDIR Base directory to place all stuff (external libs, source codes, metadatas, etc)
-- @field PRODAPP <b>[Advanced]</b> Where the external packages will be extracted
-- @field SVNURL <b>[Advanced]</b> Location of the source code to be compiled
-- @field SVNDIR <b>[Advanced]</b> Where the source code will be checked out
-- @field DEPLOYDIR <b>[Advanced]</b> Where are the 'puts' related configurations
-- @field INSTALL.TOP <b>[Advanced]</b> Where the binaries, libraries, includes and others will be place after the compilation

-- Tecmake compatibility variables
-- You could (in a very special case) redefine this to work with the compile.lua
id = require "tools.platformid"
TEC_UNAME = TEC_UNAME or os.getenv("TEC_UNAME") or id.TEC_UNAME
assert(TEC_UNAME, "ERROR: TEC_UNAME env var not defined")
TEC_SYSNAME = TEC_SYSNAME or os.getenv("TEC_SYSNAME") or id.TEC_SYSNAME
assert(TEC_SYSNAME, "ERROR: TEC_SYSNAME env var not defined")

-- Base variables to compile and install time
BASEDIR = BASEDIR or os.getenv("HOME") .."/openbus"
assert(BASEDIR or os.getenv("HOME"), "ERROR: HOME env var not defined")

PRODAPP = PRODAPP or BASEDIR .."/lib"

SVNREPURL = SVNREPURL or "svn+https://subversion.tecgraf.puc-rio.br/engdist"
SVNURL = SVNURL or SVNREPURL .. "/openbus/trunk"
SVNDIR = SVNDIR or BASEDIR .."/trunk"
DEPLOYDIR = DEPLOYDIR or SVNDIR .."/tools"
DOWNLOADDIR = DOWNLOADDIR or BASEDIR .."/packs"
PKGDIR = PKGDIR or DOWNLOADDIR .."/metadata/".. TEC_UNAME
PKGPREFIX = PKGPREFIX or "openbus-"

INSTALL = INSTALL or {}
INSTALL.TOP = INSTALL.TOP or BASEDIR .."/install"
INSTALL.BIN = INSTALL.BIN or INSTALL.TOP .."/bin/".. TEC_UNAME .."/"
INSTALL.LIB = INSTALL.LIB or INSTALL.TOP .."/libpath/".. TEC_UNAME .."/"
INSTALL.INC = INSTALL.INC or INSTALL.TOP .."/incpath/"
TMPDIR = TMPDIR or "/tmp/openbus-building_".. math.random(os.time()%100000)

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
}

-- Given a way to change platform specific variables.
-- Useful for the makepack script that needs create packages for many platforms
-- from a different TEC_UNAME machine.
function changePlatform(arch)
  assert(PKGDIR:find(TEC_UNAME), "Variable PKGDIR isn't platform specific and you are trying changePlaform!")
  assert(INSTALL.BIN:find(TEC_UNAME), "Variable INSTALL.BIN isn't platform specific and you are trying changePlaform!")
  assert(INSTALL.LIB:find(TEC_UNAME), "Variable INSTALL.LIB isn't platform specific and you are trying changePlaform!")
  return PKGDIR:gsub(TEC_UNAME,arch),
    INSTALL.BIN:gsub(TEC_UNAME,arch),
    INSTALL.LIB:gsub(TEC_UNAME,arch)
end

-- print("[ INFO ] Default configuration loaded.")

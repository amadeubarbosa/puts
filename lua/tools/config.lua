--- Default configuration used by package assistants.
-- Using the following directories structure.
-- <ul>
-- <li> prodapp/{a,b,c} = lua libs like lposix,luasocket,oil04,latt </li>
-- <li> prodapp/{d,e,f}     = base softwares like openldap,openssl </li>
-- <li> work/trunk          = svn export or checkout </li>
-- <li> work/install        = install dir to use install_files table to copy here like: <br />
-- <code> cp -r -Lf lib/$TEC_UNAME/* work/install/lib/$TEC_UNAME/ </code></li>
-- </ul>
-- The most important variables configured are documented as fields.
-- @class table
-- @name tools.config
-- @field TEC_UNAME Tecmake way to recognize the specific system identifier
-- @field TEC_SYSNAME Tecmake way to recognize the generic system identifier
-- @field BASEDIR Base directory where can exist the prodapp and work dirs
-- @field PRODAPP <b>[Advanced]</b> Where the external packages will be extracted
-- @field SVNDIR <b>[Advanced]</b> Where the source code will be checked out
-- @field DEPLOYDIR <b>[Advanced]</b> Where are the 'tools' related configurations
-- @field INSTALL.TOP <b>[Advanced]</b> Where the binaries, libraries, includes and others will be place after the compilation

-- Tecmake compatibility variables
-- You could (in a very special case) redefine this to work with the compile.lua
TEC_UNAME = TEC_UNAME or os.getenv("TEC_UNAME")
assert(TEC_UNAME or os.getenv("TEC_UNAME"), "ERROR: TEC_UNAME env var not defined")
TEC_SYSNAME = TEC_SYSNAME or os.getenv("TEC_SYSNAME")
assert(TEC_SYSNAME or os.getenv("TEC_SYSNAME"), "ERROR: TEC_SYSNAME env var not defined")

-- Base variables to compile and install time
BASEDIR = BASEDIR or os.getenv("HOME")
assert(BASEDIR or os.getenv("HOME"), "ERROR: HOME env var not defined")

WORKDIR = WORKDIR or BASEDIR .."/work"
PRODAPP = PRODAPP or BASEDIR .."/prodapp"

SVNDIR = SVNDIR or WORKDIR .."/trunk"
DEPLOYDIR = DEPLOYDIR or SVNDIR .."/tools"
PKGDIR = PKGDIR or WORKDIR .."/pkgfiles/".. TEC_UNAME

INSTALL = INSTALL or {}
INSTALL.TOP = INSTALL.TOP or WORKDIR .."/install"
INSTALL.BIN = INSTALL.BIN or INSTALL.TOP .."/bin/".. TEC_UNAME .."/"
INSTALL.LIB = INSTALL.LIB or INSTALL.TOP .."/libpath/".. TEC_UNAME .."/"
INSTALL.INC = INSTALL.INC or INSTALL.TOP .."/incpath/"
TMPDIR = TMPDIR or "/tmp/openbus-building_".. math.random(os.time()%100000)

-- We must fill the work/trunk in any way
FETCH_CMD = FETCH_CMD or "svn co https://subversion.tecgraf.puc-rio.br/engsoftware/openbus/trunk ".. SVNDIR .." || svn up ".. SVNDIR .."/"

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

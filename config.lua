-- ORGANIZATION of build tree:
-- prodapp/lib/{a,b,c} = lua libs like lposix,luasocket,oil04,latt
-- prodapp/{a,b,c}     = base softwares like openldap,openssl
-- work/trunk          = svn export or checkout
-- work/install        = install dir to use install_files table to copy here like:
--                       cp -r -Lf lib/$TEC_UNAME/* work/install/lib/$TEC_UNAME/

assert(os.getenv("HOME"), "ERROR: HOME env var not defined")
assert(os.getenv("TEC_UNAME"), "ERROR: TEC_UNAME env var not defined")
assert(os.getenv("TEC_SYSNAME"), "ERROR: TEC_SYSNAME env var not defined")

-- Tecmake compatibility variables
-- You could (in a very special case) redefine this to work with the compile.lua
TEC_UNAME = os.getenv("TEC_UNAME")
TEC_SYSNAME = os.getenv("TEC_SYSNAME")

-- Base variables to compile and install time
BASEDIR = os.getenv("HOME")
WORKDIR = BASEDIR .."/work"
PRODAPP = BASEDIR .."/prodapp"

SVNDIR = WORKDIR .."/trunk"
DEPLOYDIR = SVNDIR .."/tools"
PKGDIR = WORKDIR .."/pkgfiles/".. TEC_UNAME

INSTALL = {}
INSTALL.TOP = WORKDIR .."/install"
INSTALL.BIN = INSTALL.TOP .."/bin/".. TEC_UNAME .."/"
INSTALL.LIB = INSTALL.TOP .."/libpath/".. TEC_UNAME .."/"
INSTALL.INC = INSTALL.TOP .."/incpath/"
TMPDIR = "/tmp/openbus-building_".. math.random(os.time()%100000)

-- We must fill the work/trunk in any way
FETCH_CMD = "svn co https://subversion.tecgraf.puc-rio.br/engsoftware/openbus/trunk ".. SVNDIR .." || svn up ".. SVNDIR .."/"

-- Supported arch to makepack
SUPPORTED_ARCH = { 
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

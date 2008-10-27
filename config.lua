-- ORGANIZATION of build tree:
-- prodapp/lib/{a,b,c} = lua libs like lposix,luasocket,oil04,latt
-- prodapp/{a,b,c}     = base softwares like openldap,openssl
-- work/trunk          = svn export or checkout
-- work/install        = install dir to use install_files table to copy here like:
--                       cp -r -Lf lib/$TEC_UNAME/* work/install/lib/$TEC_UNAME/

assert(os.getenv("HOME"), "HOME env var not defined")
assert(os.getenv("TEC_UNAME"), "TEC_UNAME env var not defined")
assert(os.getenv("TEC_SYSNAME"), "TEC_SYSNAME env var not defined")

-- Base variables to compile and install time
BASEDIR = os.getenv("HOME")
WORKDIR = BASEDIR .."/work"
PRODAPP = BASEDIR .."/prodapp"
DEPLOYDIR = BASEDIR .."/tools"

SVNDIR = WORKDIR .."/trunk"
PKGDIR = WORKDIR .."/pkgfiles/".. os.getenv("TEC_UNAME")

INSTALL = {}
INSTALL.TOP = WORKDIR .."/install"
INSTALL.BIN = INSTALL.TOP .."/bin/".. os.getenv("TEC_UNAME") .."/"
INSTALL.LIB = INSTALL.TOP .."/libpath/".. os.getenv("TEC_UNAME") .."/"
INSTALL.INC = INSTALL.TOP .."/incpath/"
TMPDIR = "/tmp/openbus-building_".. math.random(os.time()%100000)

-- Tecmake compatibility variables
-- You could (in a very special case) redefine this to work with the compile.lua
TEC_UNAME = os.getenv("TEC_UNAME")
TEC_SYSNAME = os.getenv("TEC_SYSNAME")

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
	"SunOS58", 
	"SunOS510x86", 
	"Darwin811x86",
}

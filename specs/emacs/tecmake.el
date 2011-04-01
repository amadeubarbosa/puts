
(defcustom tecmake/home nil "Puts home. Must be defined" :type 'string)
(defcustom tecmake/make "make" "Defines which make to be called" :type 'string)
(defcustom tecmake/system "Linux" "" :type 'string)
(defcustom tecmake/system-major-version "2" "" :type 'string)
(defcustom tecmake/system-minor-version "6" "" :type 'string)
(defcustom tecmake/system-architecture "x64" "" :type 'string)
(defcustom tecmake/compiler-version "g4" "" :type 'string)
(defcustom tecmake/lua "lua" "Defines which lua to be called" :type 'string)

(setenv "PATH" (concat (getenv "PATH") ":" tecmake/home))
(setenv "TECMAKE_HOME" tecmake/home)
(setenv "TECMAKE_MAKE" tecmake/make)
(setenv "TEC_SYSNAME" tecmake/system)
(setenv "TEC_SYSVERSION" tecmake/system-major-version)
(setenv "TEC_SYSMINOR" tecmake/system-minor-version)
(setenv "TEC_SYSARCH" tecmake/system-architecture)

(setenv "TEC_SYSRELEASE" (concat tecmake/system-major-version "." tecmake/system-minor-version))
(setq tecmake/uname (concat tecmake/system tecmake/system-major-version
                            tecmake/system-minor-version tecmake/compiler-version
                            (if (string= tecmake/system-architecture "x64")
                                "_64")))
(setenv "TEC_UNAME" tecmake/uname)
(setenv "LUA51" tecmake/lua)

(provide 'tecmake)

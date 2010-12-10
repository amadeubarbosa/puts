
(defcustom puts/home nil "Puts home. Must be defined" :type 'string)

(setenv "PATH" (concat (getenv "PATH") ":" puts/home))
(setenv "PUTS_HOME" puts/home)

(provide 'puts)

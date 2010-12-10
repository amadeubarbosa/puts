
(defcustom mico/home nil "Mico home" :type 'string)
(defcustom mico/version "2.3.13" "Mico version" :type 'string)

(setenv "MICODIR" mico/home)
(setenv "MICOVERSION" mico/version)

(provide 'mico)

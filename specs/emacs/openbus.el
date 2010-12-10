
(defcustom openbus/home nil "Openbus home" :type 'string)

;;(setenv "MICODIR" "/home/felipe/dev/tecgraf/openbus/trunk/install")
;;(setenv "MICOVERSION" "2.3.13")

;;(setq openbus/home "/home/felipe/dev/tecgraf/openbus/trunk/install")
(setenv "OPENBUS_HOME" (concat openbus/home "/install"))
(setenv "OPENBUS_SRC" (concat openbus/home))
(setenv "LD_LIBRARY_PATH" (concat openbus/home (concat "/libpath/" tecmake/uname)))

(defcustom openbus/acs-buffer-name "*acs*" "" :type 'string)
(defcustom openbus/rgs-buffer-name "*rgs*" "" :type 'string)

(defcustom openbus/acs-process-name "*acs*" "" :type 'string)
(defcustom openbus/rgs-process-name "*rgs*" "" :type 'string)

(defun openbus/clear-cache () (interactive)
  (delete-file (concat openbus/home "/data/acs_connections.db"))
  (shell-command (concat "touch " openbus/home "/data/acs_connections.db"))
  (shell-command (concat "rm " openbus/home "/data/offers/*"))
  (message "Cache cleared (acs_connections.db and offers/*)")
)

(defun openbus/start-rgs-aux ()
  (message "Starting Openbus RGS")
  (setq openbus/rgs-process (start-process openbus/rgs-process-name openbus/rgs-buffer-name
                                   (concat openbus/home "/core/bin/run_registry_server.sh")))
  (set-process-query-on-exit-flag openbus/rgs-process nil)

  (switch-to-buffer-other-window openbus/acs-buffer-name)
  (switch-to-buffer-other-window openbus/rgs-buffer-name)
)

(defun openbus/start-rgs () (interactive)
  (message "Starting Openbus RGS")
  (setq openbus/rgs-process (start-process openbus/rgs-process-name openbus/rgs-buffer-name
                                   (concat openbus/home "/core/bin/run_registry_server.sh")))
  (set-process-query-on-exit-flag openbus/rgs-process nil)
  (switch-to-buffer-other-window openbus/rgs-buffer-name)
)

(defun openbus/start-acs () (interactive)
  (message "Starting Openbus ACS")
  (setq openbus/acs-process (start-process openbus/acs-process-name openbus/acs-buffer-name
                                   (concat openbus/home "/core/bin/run_access_control_server.sh")))
  (set-process-query-on-exit-flag openbus/acs-process nil)
  (switch-to-buffer-other-window openbus/acs-buffer-name)
)

(defun openbus/start () (interactive)
  (message "Starting Openbus ACS, wait...")
  (setq openbus/acs-process (start-process openbus/acs-process-name openbus/acs-buffer-name
                                   (concat openbus/home "/core/bin/run_access_control_server.sh")))
  (set-process-query-on-exit-flag openbus/acs-process nil)
  (run-at-time "5 seconds" nil 'openbus/start-rgs-aux)
)

(defun openbus/stop-acs () (interactive)
  (kill-buffer openbus/acs-buffer-name)
  (setq openbus/acs-process nil)
)

(defun openbus/stop-rgs () (interactive)
  (kill-buffer openbus/rgs-buffer-name)
  (setq openbus/rgs-process nil)
)

(defun openbus/stop () (interactive)
  (openbus/stop-acs)
  (openbus/stop-rgs)
)

(provide 'openbus)

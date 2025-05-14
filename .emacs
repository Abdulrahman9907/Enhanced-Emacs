;; --------------------------------------------
;; Line Numbers (Enabled by default in C)
;; --------------------------------------------

(global-display-line-numbers-mode)
(setq display-line-numbers-type t)
(setq display-line-numbers-width 4)

;; Turn off line numbers in terminal-related modes
(dolist (mode '(term-mode-hook shell-mode-hook eshell-mode-hook))
  (add-hook mode (lambda () (display-line-numbers-mode 0))))

(custom-set-faces
 '(line-number ((t (:foreground "#565656" :background "#2b2b2b"))))
 '(line-number-current-line ((t (:foreground "#ffd700" :background "#3a3a3a")))))

;; --------------------------------------------
;; Highlight Space-Related Issues Only (Visual Red Marking)
;; --------------------------------------------

(defface my-betty-warning-face
  '((t (:background "red")))
  "Red highlight for Betty style violations.")

(defvar betty-highlighting-enabled t)
(defvar betty-keywords nil)

(defun highlight-betty-violations ()
  (when betty-highlighting-enabled
    (setq betty-keywords
          `(
            ("^\\( +\\)"       (1 'my-betty-warning-face))  ; leading spaces
            ("\\( +\\)$"       (1 'my-betty-warning-face))  ; trailing spaces
            ("\t+"             (0 'my-betty-warning-face))  ; tabs
            ))
    (font-lock-add-keywords nil betty-keywords 'append)
    (font-lock-flush)))

(defun toggle-betty-highlighting ()
  (interactive)
  (setq betty-highlighting-enabled (not betty-highlighting-enabled))
  (if betty-highlighting-enabled
      (highlight-betty-violations)
    (font-lock-remove-keywords nil betty-keywords)
    (font-lock-flush))
  (message "Betty highlighting %s" (if betty-highlighting-enabled "enabled" "disabled")))

(add-hook 'c-mode-hook #'highlight-betty-violations)
(add-hook 'c++-mode-hook #'highlight-betty-violations)
(add-hook 'prog-mode-hook #'highlight-betty-violations)

;; --------------------------------------------
;; Show hint in minibuffer when cursor is over mistake
;; --------------------------------------------

(defun show-help-echo-in-minibuffer ()
  (let ((msg (get-text-property (point) 'help-echo)))
    (when (and msg (not (minibufferp))) (message "%s" msg))))
(add-hook 'post-command-hook #'show-help-echo-in-minibuffer)

;; --------------------------------------------
;; Navigation, Deletion, Undo, and Jumping
;; --------------------------------------------

(defvar betty-deleted-cache nil)

(defun betty--next-violation-position (dir)
  (let ((start (point))
        (step (if (eq dir 'forward) 1 -1)))
    (catch 'done
      (while t
        (forward-char step)
        (cond
         ((or (bobp) (eobp)) (goto-char start) (message "No more violations.") (throw 'done nil))
         ((eq (get-text-property (point) 'face) 'my-betty-warning-face) (throw 'done t)))))))

(defun next-betty-violation () (interactive) (betty--next-violation-position 'forward))
(defun previous-betty-violation () (interactive) (betty--next-violation-position 'backward))

(defun count-betty-violations ()
  (interactive)
  (let ((count 0))
    (save-excursion
      (goto-char (point-min))
      (while (< (point) (point-max))
        (when (eq (get-text-property (point) 'face) 'my-betty-warning-face)
          (setq count (1+ count)))
        (forward-char 1)))
    (message "Violations: %d" count)))

(defun delete-betty-spaces-and-tabs ()
  (interactive)
  (setq betty-deleted-cache '())
  (save-excursion
    (goto-char (point-min))
    (while (not (eobp))
      (when (and (eq (get-text-property (point) 'face) 'my-betty-warning-face)
                 (string-match-p "[ \t]" (buffer-substring (point) (1+ (point)))))
        (let* ((start (point))
               (end (next-single-property-change start 'face nil (point-max))))
          (push (list start (buffer-substring start end)) betty-deleted-cache)
          (delete-region start end)))
      (forward-char 1)))
  (message "Deleted %d space/tab violations (C-c u to undo)." (length betty-deleted-cache)))

(defun undo-betty-deletion ()
  (interactive)
  (if (null betty-deleted-cache)
      (message "Nothing to undo.")
    (save-excursion
      (dolist (entry (reverse betty-deleted-cache))
        (goto-char (car entry)) (insert (cadr entry))))
    (setq betty-deleted-cache nil)
    (message "Undo complete.")))

;; --------------------------------------------
;; Betty Analysis - Real Betty Checker
;; --------------------------------------------

(defvar betty-program-path "betty"
  "Path to the Betty program executable.")

(defvar betty-output-buffer-name "*Betty Output*")

(defun run-betty-on-current-file ()
  "Run the actual Betty program on the current file and display output."
  (interactive)
  (let ((filename (buffer-file-name)))
    (if (not filename)
        (message "Error: Buffer is not associated with a file")
      ;; No longer automatically saving the file
      
      ;; Run Betty command
      (let* ((cmd (concat betty-program-path " " (shell-quote-argument filename)))
             (output-buffer (get-buffer-create betty-output-buffer-name))
             (result (shell-command-to-string cmd)))
        
        ;; Set up output buffer
        (with-current-buffer output-buffer
          (let ((inhibit-read-only t))
            (erase-buffer)
            (special-mode) ; Read-only mode
            
            ;; Header
            (insert (propertize "Betty Style Check Results\n\n" 
                               'face '(:height 1.5 :foreground "yellow" :weight bold)))
            (insert (format "File: %s\n" filename))
            (insert (format "Command: %s\n\n" cmd))
            
            ;; Output
            (if (string-empty-p result)
                (insert (propertize "No style errors found! Your code is Betty-compliant.\n" 
                                   'face '(:foreground "green" :weight bold)))
              (insert result))
            
            ;; Make error messages clickable to jump to line
            (goto-char (point-min))
            (while (re-search-forward "\\([^:]+\\):\\([0-9]+\\):" nil t)
              (let ((file (match-string 1))
                    (line (string-to-number (match-string 2)))
                    (start (match-beginning 0))
                    (end (match-end 0)))
                (when (string= file filename)
                  (put-text-property start end 'mouse-face 'highlight)
                  (put-text-property start end 'help-echo "Click to jump to this line")
                  (put-text-property start end 'betty-line line)
                  (put-text-property start end 'keymap 
                                     (let ((map (make-sparse-keymap)))
                                       (define-key map [mouse-1] 
                                         `(lambda ()
                                            (interactive)
                                            (find-file ,file)
                                            (goto-char (point-min))
                                            (forward-line (1- ,line))))
                                       map)))))))
        
        ;; Display the output buffer
        (if (get-buffer-window betty-output-buffer-name)
            (with-current-buffer output-buffer
              (let ((win (get-buffer-window (current-buffer))))
                (with-selected-window win
                  (goto-char (point-min)))))
          (display-buffer-in-side-window
           output-buffer
           '((side . bottom)
             (window-height . 10))))
        
        (message "Betty check complete")))))

;; Toggle function for Betty output panel
(defun toggle-betty-output-panel ()
  "Toggle the Betty output panel by running Betty on current file."
  (interactive)
  (if (get-buffer-window betty-output-buffer-name)
      (delete-window (get-buffer-window betty-output-buffer-name))
    (run-betty-on-current-file)))

;; Auto-run Betty on save (optional)
(defvar betty-check-on-save nil
  "If non-nil, automatically run Betty check when saving C files.")

(defun betty-check-on-save-hook ()
  "Run Betty check if enabled."
  (when (and betty-check-on-save
             (or (eq major-mode 'c-mode)
                 (eq major-mode 'c++-mode)))
    (run-betty-on-current-file)))

(add-hook 'after-save-hook #'betty-check-on-save-hook)

;; Update mode line button to run actual Betty
(defvar betty-mode-line-button
  '(:eval
    (propertize " Betty "
                'face '(:background "orange" :foreground "black")
                'mouse-face '(:background "yellow" :foreground "black")
                'help-echo "Click to run Betty style checker"
                'local-map (let ((map (make-sparse-keymap)))
                             (define-key map [mode-line mouse-1]
                               'run-betty-on-current-file)
                             map))))

(put 'betty-mode-line-button 'risky-local-variable t)
(add-to-list 'mode-line-format betty-mode-line-button 'append)

;; --------------------------------------------
;; Shortcut Legend (C-c l)
;; --------------------------------------------

(defun toggle-betty-shortcut-legend ()
  (interactive)
  (let ((buf "*Betty Shortcuts*"))
    (if (get-buffer-window buf)
        (delete-window (get-buffer-window buf))
      (with-help-window buf
        (with-current-buffer buf
          (insert (propertize "Custom Shortcuts\n" 'face '(:foreground "yellow" :weight bold)))
          (dolist (key '(
                         "C-c n — Next violation (highlighting)"
                         "C-c p — Previous violation (highlighting)"
                         "C-c c — Count violations (highlighting)"
                         "C-c d — Delete spaces/tabs"
                         "C-c u — Undo delete"
                         "C-c x — Toggle highlighting"
                         "C-c b — Run Betty checker (toggle)"
                         "C-c l — This legend"))
            (insert (concat "  " key "\n"))))))))

;; --------------------------------------------
;; Keybindings
;; --------------------------------------------

(global-set-key (kbd "C-c n") #'next-betty-violation)
(global-set-key (kbd "C-c p") #'previous-betty-violation)
(global-set-key (kbd "C-c c") #'count-betty-violations)
(global-set-key (kbd "C-c d") #'delete-betty-spaces-and-tabs)
(global-set-key (kbd "C-c u") #'undo-betty-deletion)
(global-set-key (kbd "C-c x") #'toggle-betty-highlighting)
(global-set-key (kbd "C-c b") #'toggle-betty-output-panel)
(global-set-key (kbd "C-c l") #'toggle-betty-shortcut-legend)

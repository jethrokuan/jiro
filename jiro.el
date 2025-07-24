;;; jiro.el --- Read-only view using magit-section for jujutsu projects -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2025 Jethro Kuan
;;
;; Author: Jethro Kuan <jethrokuan95@gmail.com>
;; Maintainer: Jethro Kuan <jethrokuan95@gmail.com>
;; Created: July 23, 2025
;; Modified: July 23, 2025
;; Version: 0.0.1
;; Keywords: vc tools
;; Homepage: https://github.com/jethrokuan/jiro
;; Package-Requires: ((emacs "27.1") (magit "4.3.8"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;; jiro provides a read-only view using magit-section for a current jujutsu project.
;; It is a very unambitious project, providing a nicer view for `jj diff` and `jj log`.
;;
;; Main commands:
;; - `jiro-status': Pop up a read-only buffer showing jj status with magit-section formatting
;;
;;; Code:

(require 'magit)
(require 'ansi-color)

(defgroup jiro nil
  "Read-only view for jujutsu projects."
  :group 'tools)

(defcustom jiro-jj-executable "jj"
  "Path to the jj executable."
  :type 'string
  :group 'jiro)

(defcustom jiro-diff-tool "difft"
  "Diff tool to use with jj diff --tool option.
Common values: \":git\", \":builtin\", or external tools like \"difftastic\"."
  :type 'string
  :group 'jiro)

(defvar-local jiro-project-root nil
  "Project root directory for the current jiro buffer.")

(defvar jiro-buffer-name-prefix "*jiro-status"
  "Prefix for jiro status buffer names.")

(define-derived-mode jiro-mode magit-section-mode "Jiro"
  "Mode for jiro buffers."
  :group 'jiro
  (define-key jiro-mode-map (kbd "g") #'jiro-status-refresh)
  (define-key jiro-mode-map (kbd "RET") #'jiro-goto-line))

(defun jiro--get-project-root ()
  "Get the root directory of the current jujutsu project."
  (let ((default-directory (or jiro-project-root default-directory)))
    (with-temp-buffer
      (let ((exit-code (call-process jiro-jj-executable nil t nil "root")))
        (if (zerop exit-code)
            (string-trim (buffer-string))
          (error "Not in a jujutsu repository"))))))

(defun jiro--run-jj (args)
  "Run jj with ARGS and return the output."
  (let ((default-directory (or jiro-project-root default-directory)))
    (with-temp-buffer
      (let ((exit-code (apply #'call-process jiro-jj-executable nil t nil args)))
        (if (zerop exit-code)
            (buffer-string)
          (let ((error-msg (string-trim (buffer-string))))
            (if (string-match-p "There is no jj repo" error-msg)
                (error "Not in a jujutsu repository. Please run jiro-status from within a jj repository")
              (error "jj command failed: %s" error-msg))))))))

(defun jiro--get-current-change-info ()
  "Get information about the current change set."
  (let ((log-info (jiro--run-jj '("log" "-r" "@" "--no-graph" "-T" "change_id ++ \" \" ++ description")))
        (status-info (jiro--run-jj '("status" "--color=always"))))
    (format "%s\n\n%s" (string-trim log-info) (string-trim status-info))))

(defun jiro--strip-ansi-codes (string)
  "Remove ANSI escape codes from STRING."
  (ansi-color-filter-apply string))

(defun jiro--parse-diff-output (diff-output)
  "Parse DIFF-OUTPUT and return a list of file diffs."
  (if (string-empty-p (string-trim diff-output))
      '(("No changes" "No differences found in the current change."))
    (let ((files '())
          (current-file nil)
          (current-diff '())
          (lines (split-string diff-output "\n")))
      (dolist (line lines)
        (cond
         ;; jj diff format: "path/to/file.ext --- FORMAT"
         ((string-match "^\\([^[:space:]]+\\) --- " line)
          (when current-file
            (push (list current-file (string-join (reverse current-diff) "\n")) files))
          ;; Strip ANSI codes from file name for clean section titles
          (setq current-file (jiro--strip-ansi-codes (match-string 1 line)))
          (setq current-diff (list line)))
         ;; Standard git diff format (fallback)
         ((string-match "^diff --git a/\\(.*\\) b/\\(.*\\)$" line)
          (when current-file
            (push (list current-file (string-join (reverse current-diff) "\n")) files))
          (setq current-file (match-string 1 line))
          (setq current-diff (list line)))
         ;; Accumulate all lines for current file
         (t
          (if current-file
              (push line current-diff)
            ;; If we haven't found a file header yet, start collecting
            (unless (string-empty-p (string-trim line))
              (setq current-file "Changes")
              (setq current-diff (list line)))))))
      ;; Handle the last file
      (when current-file
        (push (list current-file (string-join (reverse current-diff) "\n")) files))
      ;; Return parsed files or fallback to raw output
      (if files
          (reverse files)
        (list (list "Raw Diff Output" diff-output))))))


(defun jiro--insert-status-info (status-info)
  "Insert STATUS-INFO section without title or collapse."
  (let ((start (point)))
    (insert (string-trim status-info) "\n\n")
    ;; Process ANSI color codes in status info
    (ansi-color-apply-on-region start (point))))

(defun jiro--insert-file-diff (file-name diff-content)
  "Insert a file diff section for FILE-NAME with DIFF-CONTENT."
  (magit-insert-section (file file-name t)
    (magit-insert-heading file-name)
    (let ((start (point))
          (lines (split-string diff-content "\n"))
          (filtered-lines '()))
      ;; Skip the first line if it's similar to the section title
      (dolist (line (if (and lines (string-match-p (regexp-quote file-name) (car lines)))
                        (cdr lines)
                      lines))
        (push line filtered-lines))
      (when filtered-lines
        (insert (string-join (reverse filtered-lines) "\n") "\n\n")
        ;; Process ANSI color codes
        (ansi-color-apply-on-region start (point))))))

(defun jiro--refresh-buffer ()
  "Refresh the current jiro buffer content."
  (let* ((status-info (jiro--run-jj '("status" "--color=always")))
         (diff-output (jiro--run-jj `("diff" "--color=always" "--tool" ,jiro-diff-tool)))
         (file-diffs (jiro--parse-diff-output diff-output)))
    (let ((inhibit-read-only t))
      (erase-buffer)
      (magit-insert-section (jiro-root)
        (jiro--insert-status-info status-info)
        (dolist (file-diff file-diffs)
          (jiro--insert-file-diff (car file-diff) (cadr file-diff))))
      (goto-char (point-min)))))

(defun jiro--parse-line-number (line)
  "Parse line number from a diff LINE."
  (cond
   ;; Match jj diff format with line numbers (e.g., " 42   content")
   ((string-match "^[[:space:]]*\\([0-9]+\\)[[:space:]]" line)
    (string-to-number (match-string 1 line)))
   ;; Match unified diff format (e.g., "@@ -10,7 +10,7 @@")
   ((string-match "^@@.*\\+\\([0-9]+\\)" line)
    (string-to-number (match-string 1 line)))
   (t nil)))

(defun jiro--get-current-file ()
  "Get the file name from the current magit section."
  (let ((section (magit-current-section)))
    (when section
      (cond
       ((eq (oref section type) 'file)
        (oref section value))
       ((oref section parent)
        (jiro--get-current-file-from-parent (oref section parent)))
       (t nil)))))

(defun jiro--get-current-file-from-parent (section)
  "Recursively get file name from parent SECTION."
  (when section
    (if (eq (oref section type) 'file)
        (oref section value)
      (when (oref section parent)
        (jiro--get-current-file-from-parent (oref section parent))))))

(defun jiro-goto-line ()
  "Navigate to the line in the file corresponding to the current diff line."
  (interactive)
  (let* ((current-line (thing-at-point 'line t))
         (line-number (when current-line (jiro--parse-line-number current-line)))
         (file-name (jiro--get-current-file)))
    (cond
     ((and file-name line-number)
      (find-file file-name)
      (goto-char (point-min))
      (forward-line (1- line-number))
      (message "Jumped to %s:%d" file-name line-number))
     (file-name
      (find-file file-name)
      (message "Opened %s (no line number found)" file-name))
     (t
      (message "No file or line information found at point")))))

(defun jiro-status-refresh ()
  "Refresh the jiro status buffer."
  (interactive)
  (when (eq major-mode 'jiro-mode)
    (jiro--refresh-buffer)
    (message "Refreshed jiro status")))

(defun jiro--generate-buffer-name (project-root)
  "Generate a unique buffer name for PROJECT-ROOT."
  (let* ((project-name (file-name-nondirectory (directory-file-name project-root)))
         (base-name (format "%s-%s*" jiro-buffer-name-prefix project-name))
         (counter 1)
         (buffer-name base-name))
    ;; Handle deduplication if buffer already exists
    (while (and (get-buffer buffer-name)
                (not (with-current-buffer buffer-name
                       (and (eq major-mode 'jiro-mode)
                            (string= jiro-project-root project-root)))))
      (setq buffer-name (format "%s-%s<%d>*" jiro-buffer-name-prefix project-name counter))
      (setq counter (1+ counter)))
    buffer-name))

;;;###autoload
(defun jiro-status ()
  "Show jj status in a magit-section buffer."
  (interactive)
  (let* ((project-root (jiro--get-project-root))
         (buffer-name (jiro--generate-buffer-name project-root))
         (buffer (get-buffer-create buffer-name)))
    (with-current-buffer buffer
      (jiro-mode)
      (setq jiro-project-root project-root)
      (jiro--refresh-buffer))
    (switch-to-buffer buffer)))

(provide 'jiro)
;;; jiro.el ends here

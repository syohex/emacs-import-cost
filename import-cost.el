;;; import-cost.el --- import cost -*- lexical-binding: t; -*-

;; Copyright (C) 2020 by Shohei YOSHIDA

;; Author: Shohei YOSHIDA <syohex@gmail.com>
;; URL: https://github.com/syohex/emacs-import-cost
;; Version: 0.01
;; Package-Requires: ((emacs "27.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Emacs port of import-cost VScode extension

;;; Code:

(require 'cl-lib)
(require 'json)

(defgroup import-cost nil
  "import-cost for emacs"
  :group 'js)

(defface import-cost
  '((((class color) (background light))
     (:foreground "magenta" :weight bold))
    (((class color) (background dark))
     (:foreground "green" :weight bold)))
  "Face of import size")

(defun import-cost--package-root ()
  (file-name-directory (file-name-directory (locate-library "import-cost"))))

(defun import-cost--to-readable-size (size)
  (cond ((>= size 1000000) (format "%.1f MB" (/ size 1000000.0)))
        ((>= size 1000) (format "%.1f KB" (/ size 1000.0)))
        (t (format "%d B" size))))

(defun import-cost--put-package-info (package)
  (let ((line (assoc-default 'line package))
        (size (assoc-default 'size package))
        (gzip (assoc-default 'gzip package)))
    (goto-char (point-min))
    (forward-line (1- line))
    (let* ((eol (line-end-position))
           (ov (make-overlay eol eol))
           (size-str (format " %s (gzipped: %s)"
                             (import-cost--to-readable-size size)
                             (import-cost--to-readable-size gzip))))
      (overlay-put ov 'after-string (propertize size-str 'face 'import-cost))
      (overlay-put ov 'import-cost t))))

(defun import-cost--parse-response (output buffer)
  (let* ((res (json-read-from-string output))
         (event (assoc-default 'event res)))
    (when (string= event "error")
      (error "Failed: %s" (assoc-default 'error res)))
    (with-current-buffer buffer
      (save-restriction
        (widen)
        (cl-loop for package across (assoc-default 'data res)
                 do
                 (save-excursion
                   (import-cost--put-package-info package)))))))

;;;###autoload
(defun import-cost ()
  (interactive)
  (import-cost-clear)
  (let ((file (buffer-file-name))
        (content (buffer-string))
        (buffer (current-buffer))
        (root (import-cost--package-root))
        (proc-buf-name " *import-cost*"))
    (unless (file-directory-p (concat root "node_modules"))
      (error "Please setup by `M-x import-cost-setup'"))
    (when (get-buffer proc-buf-name)
      (kill-buffer proc-buf-name))
    (let* ((proc-buf (get-buffer-create proc-buf-name))
           (default-directory root)
           (proc (start-file-process "import-cost" proc-buf "node" "src/index.js" file)))
      (set-process-query-on-exit-flag proc nil)
      (process-send-string proc content)
      (process-send-eof proc)
      (set-process-filter
       proc
       (lambda (_proc output)
         (import-cost--parse-response output buffer)))
      (set-process-sentinel
       proc
       (lambda (proc _event)
         (when (eq (process-status proc) 'exit)
           (kill-buffer proc-buf)))))))

;;;###autoload
(defun import-cost-clear ()
  (interactive)
  (save-restriction
    (widen)
    (remove-overlays (point-min) (point-max) 'import-cost t)))

;;;###autoload
(defun import-cost-setup ()
  (interactive)
  (let* ((default-directory (import-cost--package-root))
         (proc (start-file-process "import-cost-setup" nil "npm" "install")))
    (set-process-query-on-exit-flag proc nil)
    (set-process-sentinel
     proc
     (lambda (proc _event)
       (when (eq (process-status proc) 'exit)
         (if (zerop (process-exit-status proc))
             (message "Success to setup import-cost")
           (message "Failed to setup import-cost")))))))

(provide 'import-cost)

;;; import-cost.el ends here

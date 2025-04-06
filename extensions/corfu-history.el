;;; corfu-history.el --- Sorting by history for Corfu -*- lexical-binding: t -*-

;; Copyright (C) 2022-2025 Free Software Foundation, Inc.

;; Author: Daniel Mendler <mail@daniel-mendler.de>
;; Maintainer: Daniel Mendler <mail@daniel-mendler.de>
;; Created: 2022
;; Version: 2.0
;; Package-Requires: ((emacs "28.1") (compat "30") (corfu "2.0"))
;; URL: https://github.com/minad/corfu

;; This file is part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Enable `corfu-history-mode' to sort candidates by their history
;; position.  Maintain a list of recently selected candidates.  In order
;; to save the history across Emacs sessions, enable `savehist-mode' and
;; add `corfu-history' to `savehist-additional-variables'.
;;
;; (corfu-history-mode 1)
;; (savehist-mode 1)
;; (add-to-list 'savehist-additional-variables 'corfu-history)

;;; Code:

(require 'corfu)
(eval-when-compile
  (require 'cl-lib))

(defvar corfu-history nil
  "History of Corfu candidates.
The maximum length is determined by the variable `history-length'
or the property `history-length' of `corfu-history'.")

(defvar corfu-history--hash nil
  "Hash table of Corfu candidates.")

(defcustom corfu-history-duplicate 10
  "Maximal number of history positions gained by duplicate history elements.
The more often a duplicate element occurs in the history, the earlier it
appears in the completion list.  The position gain decays exponentially
with `corfu-history-decay'.  Note that duplicates occur only if
`history-delete-duplicates' is disabled."
  :type 'number
  :group 'corfu)

(defcustom corfu-history-decay 0.005
  "Exponential decay for the position gain of duplicate elements.
See also `corfu-history-duplicate'."
  :type 'float
  :group 'corfu)

(defun corfu-history--sort-predicate (x y)
  "Sorting predicate which compares X and Y."
  (or (< (cdr x) (cdr y))
      (and (= (cdr x) (cdr y))
           (corfu--length-string< (car x) (car y)))))

(defun corfu-history--sort (cands)
  "Sort CANDS by history."
  (unless corfu-history--hash
    (let ((ht (make-hash-table :test #'equal :size (length corfu-history))))
      (cl-loop for elem in corfu-history for idx from 0
               for w = (if-let ((w (gethash elem ht)))
                           ;; Reduce duplicate weight with exponential decay.
                           (- w (round (* corfu-history-duplicate
                                          (exp (* -1.0 corfu-history-decay idx)))))
                         ;; Never outrank the most recent element.
                         (if (= idx 0) (/ most-negative-fixnum 2) idx))
               do (puthash elem w ht))
      (setq corfu-history--hash ht)))
  (cl-loop for ht = corfu-history--hash for max = most-positive-fixnum
           for cand on cands do
           (setcar cand (cons (car cand) (gethash (car cand) ht max))))
  (setq cands (sort cands #'corfu-history--sort-predicate))
  (cl-loop for cand on cands do (setcar cand (caar cand)))
  cands)

;;;###autoload
(define-minor-mode corfu-history-mode
  "Update Corfu history and sort completions by history."
  :global t :group 'corfu
  (if corfu-history-mode
      (add-function :override corfu-sort-function #'corfu-history--sort)
    (remove-function corfu-sort-function #'corfu-history--sort)))

(cl-defmethod corfu--insert :before (_status &context (corfu-history-mode (eql t)))
  (when (>= corfu--index 0)
    (add-to-history 'corfu-history
                    (substring-no-properties
                     (nth corfu--index corfu--candidates)))
    (setq corfu-history--hash nil)))

(provide 'corfu-history)
;;; corfu-history.el ends here

(set-language-environment "Japanese")

; mozc settings
(require 'mozc)
(setq default-input-method "japanese-mozc")

; font settings
(cond (window-system
  (create-fontset-from-ascii-font
    "VL Gothic"
    nil
    "Emacs_Console")
  (set-fontset-font
    "fontset-Emacs_Console"
    'unicode
    "VL Gothic"
    nil
    'append)
  (set-fontset-font
    "fontset-Emacs_Console"
    '(#x01F000 . #x01FFFF)
    "Twitter Color Emoji"
    nil
    'prepend)
  (add-to-list
    'default-frame-alist
    '(font . "fontset-Emacs_Console"))))

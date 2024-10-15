(set-language-environment "Japanese")

; mozc settings
(require 'mozc)
(setq default-input-method "japanese-mozc")

; font settings
(cond (window-system
  (add-to-list 'default-frame-alist
               '(font . "Luxi Mono-10"))
  (set-fontset-font (frame-parameter nil 'font)
     'unicode
     '("VL Gothic" . "unicode-bmp"))))

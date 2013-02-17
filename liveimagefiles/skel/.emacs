(set-language-environment "Japanese")

; anthy settings
;(load-library "anthy")
;(setq default-input-method 'japanese-anthy)

; mozc settings
(require 'mozc)
(setq default-input-method "japanese-mozc")

; font settings
(cond (window-system
  (set-default-font "Luxi Mono-10")
  (set-fontset-font (frame-parameter nil 'font)
     'unicode
     '("VL Gothic" . "unicode-bmp"))))

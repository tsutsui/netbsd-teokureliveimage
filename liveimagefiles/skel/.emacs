(set-language-environment "Japanese")
(load-library "anthy")
(setq default-input-method 'japanese-anthy)
;
(cond (window-system
  (set-default-font "Luxi Mono-10")
  (set-fontset-font (frame-parameter nil 'font)
     'unicode
     '("VL Gothic" . "unicode-bmp"))))

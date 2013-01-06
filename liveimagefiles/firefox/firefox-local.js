// choose useragent locale per LANG
pref("intl.locale.matchOS", true);

// use default en-US on searchplugin regardless of LANG
pref("distribution.searchplugins.defaultLocale", "en-US");

// enable addons "installed and owned by Firefox" by default
// (note this need to be loaded before the default firefox.js)
pref("extensions.autoDisableScopes", 11);

// enable add-on selection dialog on update
pref("extensions.shownSelectionUI", true);

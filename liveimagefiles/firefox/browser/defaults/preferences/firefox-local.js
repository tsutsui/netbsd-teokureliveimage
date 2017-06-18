// disable "default browser" check on startup
pref("browser.shell.checkDefaultBrowser", false);

// enable addons "installed and owned by Firefox" by default
// (note this need to be loaded before the default firefox.js)
pref("extensions.autoDisableScopes", 11);

// enable add-on selection dialog on update
pref("extensions.shownSelectionUI", true);

// disable electrolysis (e10s) temporarily until it's stable on NetBSD
pref("browser.tabs.remote.autostart.2", false);

// Live-reload the profile's userChrome.css.
//
// Loaded once per browser session by colourme.cfg (autoconfig). The profile's
// userChrome.css is a symlink to colourme's runtime file, so watch that file
// directly; nsIFile does not follow the symlink for lastModifiedTime. The sheet
// is re-registered with a cache-busting query so the style-sheet service picks
// up the new contents without a browser restart.
//
// The timer callback and timer are kept on globalThis: a repeating nsITimer
// does not keep its JS callback alive, and a collected callback stops firing
// after the first tick.
let FILE = null;
let SHEETS = null;
let registered = null;
let lastModified = -1;

const apply = () => {
  try {
    if (registered) {
      SHEETS.unregisterSheet(registered, SHEETS.USER_SHEET);
      registered = null;
    }
    if (!FILE.exists()) return;
    lastModified = FILE.lastModifiedTime;
    registered = Services.io.newURI(
      Services.io.newFileURI(FILE).spec + "?colourme=" + Date.now(),
    );
    SHEETS.loadAndRegisterSheet(registered, SHEETS.USER_SHEET);
  } catch (e) {
    try {
      Services.prefs.setStringPref("colourme.zen.error", String(e));
      Services.prefs.savePrefFile(null);
    } catch (e2) {}
  }
};

try {
  const HOME = Services.dirsvc.get("Home", Ci.nsIFile);
  FILE = HOME.clone();
  FILE.append(".local");
  FILE.append("state");
  FILE.append("colourme");
  FILE.append("zen-userChrome.css");
  SHEETS = Cc["@mozilla.org/content/style-sheet-service;1"].getService(
    Ci.nsIStyleSheetService,
  );

  apply();

  const callback = {
    notify() {
      try {
        const exists = FILE.exists();
        const modified = exists ? FILE.lastModifiedTime : -1;
        if (modified !== lastModified) apply();
      } catch (e) {}
    },
  };
  globalThis.__colourmeZenCallback = callback;
  const timer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
  globalThis.__colourmeZenTimer = timer;
  timer.initWithCallback(callback, 1000, Ci.nsITimer.TYPE_REPEATING_PRECISE);
} catch (e) {
  try {
    Services.prefs.setStringPref("colourme.zen.error", String(e));
    Services.prefs.savePrefFile(null);
  } catch (e2) {}
}

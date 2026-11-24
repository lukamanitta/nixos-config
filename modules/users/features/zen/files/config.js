// Zen autoconfig: load the colourme live-reload module.
//
// Installed as colourme.cfg in the Zen application directory; the pref file
// defaults/pref/00-colourme-autoconfig.js points Firefox's autoconfig loader
// at it. The profile's chrome/colourme/chrome.manifest (written by
// modules/users/features/zen-browser.nix) maps chrome://colourme/ to that
// directory, which is the only scheme ES modules may be imported from here.
try {
  const PROFILE = Services.dirsvc.get("ProfD", Ci.nsIFile);
  const MANIFEST = PROFILE.clone();
  MANIFEST.append("chrome");
  MANIFEST.append("colourme");
  MANIFEST.append("chrome.manifest");
  if (MANIFEST.exists()) {
    Components.manager
      .QueryInterface(Ci.nsIComponentRegistrar)
      .autoRegister(MANIFEST);
    ChromeUtils.importESModule("chrome://colourme/content/colourme.sys.mjs");
  }
} catch (e) {
  try {
    Services.prefs.setStringPref("colourme.zen.error", String(e));
    Services.prefs.savePrefFile(null);
  } catch (e2) {}
}

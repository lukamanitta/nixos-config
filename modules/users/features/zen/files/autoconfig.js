// Installed as defaults/pref/00-colourme-autoconfig.js in the unwrapped Zen
// package. It points Firefox's autoconfig loader at colourme.cfg (also in the
// application dir) and disables the autoconfig sandbox, which the script's
// privileged APIs need. The prefix keeps it clear of the wrapper's own
// autoconfig.js.
pref("general.config.filename", "colourme.cfg");
pref("general.config.obscure_value", 0);
pref("general.config.sandbox_enabled", false);

{ lib, ... }:

# Registry of desktop environments. A host/user selects exactly one via
# `my.desktops.environment`; the compositor feature (`hyprland`) is shared
# between them. LitheDE is the default, out-of-the-box DE (docs/LITHEDE.md);
# LiquoRice is the personal, in-progress Quickshell DE.
{
  options.my.desktops.environment = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "lithe"
        "liquorice"
      ]
    );
    default = "lithe";
    description = ''
      Active desktop environment. `null` runs the shared compositor with no
      shell (no bar, launcher, notifications, or OSD).
    '';
  };

  options.my.desktops.lockOnStart = lib.mkEnableOption ''
    locking the session immediately after login, so a Quickshell lock surface
    acts as the login screen (see DECISIONS D23)
  '';

  options.my.desktops.autologin = lib.mkEnableOption ''
    logging the user in on tty1 and exec'ing the compositor from the login
    shell (used with `lockOnStart` to make the lock screen the login UI)
  '';
}

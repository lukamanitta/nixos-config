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
}

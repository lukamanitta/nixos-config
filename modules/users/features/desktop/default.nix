{ ... }:

# The "desktop" user feature: the compositor-agnostic pieces of a graphical
# session — the program/service role interface plus the features that provide
# them. The compositor itself (e.g. hyprland) is a separate feature the user
# imports alongside this one.
{
  imports = [
    ./programs.nix
    ./removable-media.nix
  ];

  # Declarative equivalent of the Arch dotfiles' `gsettings set
  # org.gnome.desktop.interface color-scheme "prefer-dark"`: tells
  # GTK4/libadwaita and the XDG desktop portal that the user prefers dark.
  # Per-DE toolkit theming (GTK3/Qt/icons) stays with the desktop modules.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
}

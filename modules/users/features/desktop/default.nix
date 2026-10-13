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
}

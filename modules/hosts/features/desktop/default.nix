{ ... }:

# The "desktop" host feature: what a graphical machine needs, independent of
# the compositor choice. The compositor itself (e.g. hyprland) is a separate
# feature the host imports alongside this one.
{
  imports = [
    ./removable-media.nix
  ];
}

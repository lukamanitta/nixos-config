{
  config,
  lib,
  pkgs,
  ...
}:

# LitheDE window controls: hyprbars server-side title bars with
# close/float/fullscreen buttons (macOS-ish traffic lights). Gated on
# `my.desktops.lithe.windowControls` because the plugin is version-locked to
# Hyprland (docs/LITHEDE.md risks).
#
# The plugin is loaded and configured at `hyprland.start` via a single chained
# `hyprctl` command. We deliberately do NOT use HM's `plugins` option or
# `hl.plugin.hyprbars.add_button`: HM loads plugins in the `hyprland.start`
# hook, so config-scope plugin calls would run before the plugin exists.
let
  enabled = config.my.desktops.environment == "lithe";
  t = config.my.desktops.lithe.tokens;

  hyprbars = pkgs.hyprlandPlugins.hyprbars;

  kw = path: value: "hyprctl keyword 'plugin:hyprbars:${path}' '${value}'";
  btn =
    bg: icon: action:
    "hyprctl keyword 'plugin:hyprbars:hyprbars-button' 'rgb(${bg}), 10, ${icon}, ${action}'";

  cmd = lib.concatStringsSep " && " [
    "hyprctl plugin load '${hyprbars}/lib/libhyprbars.so'"
    (kw "bar_height" "28")
    (kw "bar_blur" "1")
    (kw "bar_padding" "${toString t.space.sm}")
    (kw "bar_button_padding" "${toString t.space.xs}")
    (kw "bar_buttons_alignment" "left")
    (kw "icon_on_hover" "1")
    (kw "on_double_click" "hyprctl dispatch fullscreen 1")
    (btn "ff5f57" "x" "hyprctl dispatch killactive")
    (btn "febc2e" "-" "hyprctl dispatch togglefloating")
    (btn "28c840" "+" "hyprctl dispatch fullscreen 1")
  ];
in
{
  options.my.desktops.lithe.windowControls = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable hyprbars window title bars with buttons.";
  };

  config = lib.mkIf (enabled && config.my.desktops.lithe.windowControls) {
    my.hyprland.autostart = lib.mkAfter [ cmd ];
  };
}

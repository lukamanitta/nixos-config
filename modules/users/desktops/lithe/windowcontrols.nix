{
  config,
  lib,
  pkgs,
  ...
}:

# LitheDE window controls: hyprbars title bars with close/float/fullscreen
# buttons (macOS-ish traffic lights). Gated on
# `my.desktops.lithe.windowControls` because the plugin is version-locked to
# Hyprland (docs/LITHEDE.md risks).
#
# hyprbars 0.55 dropped the `hyprbars-button` config keyword: buttons are only
# added through the plugin's Lua API (`hl.plugin.hyprbars.add_button`), which
# exists only once the plugin is loaded. Home Manager loads plugin packages
# *after* the config is parsed — in the `hyprland.start` hook, as an async
# `hyprctl plugin load` — so we load the plugin ourselves at config-parse time
# with `hl.plugin.load(...)` (deterministic; this is what upstream HM later
# adopted). The buttons sit behind a nil-guard: the first parse schedules the
# load (guard false), then the reload that follows the load re-runs this block
# with the plugin present and actually registers the buttons.
let
  enabled = config.my.desktops.environment == "lithe";
  t = config.my.desktops.lithe.tokens;

  hyprbars = pkgs.hyprlandPlugins.hyprbars;
  hyprbarsPath = "${hyprbars}/lib/lib${hyprbars.pname}.so";

  toLua = lib.generators.toLua { };
in
{
  options.my.desktops.lithe.windowControls = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable hyprbars window title bars with buttons.";
  };

  config = lib.mkIf (enabled && config.my.desktops.lithe.windowControls) {
    wayland.windowManager.hyprland.extraConfig = ''
      hl.plugin.load(${toLua hyprbarsPath})

      if hl.plugin.hyprbars ~= nil then
        hl.config({
          plugin = {
            hyprbars = {
              bar_height = 28,
              bar_blur = true,
              bar_padding = ${toString t.space.sm},
              bar_button_padding = ${toString t.space.xs},
              bar_buttons_alignment = "left",
              icon_on_hover = true,
              on_double_click = "hyprctl dispatch fullscreen 1",
            },
          },
        })

        hl.plugin.hyprbars.add_button({ bg_color = "rgb(ff5f57)", fg_color = "rgb(000000)", size = 10, icon = "x", action = "hyprctl dispatch killactive" })
        hl.plugin.hyprbars.add_button({ bg_color = "rgb(febc2e)", fg_color = "rgb(000000)", size = 10, icon = "-", action = "hyprctl dispatch togglefloating" })
        hl.plugin.hyprbars.add_button({ bg_color = "rgb(28c840)", fg_color = "rgb(000000)", size = 10, icon = "+", action = "hyprctl dispatch fullscreen 1" })
      end
    '';
  };
}

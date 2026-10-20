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
# hyprbars 0.55 registers the `hyprbars-button` keyword only for legacy configs;
# under the Lua config type buttons are only added through the plugin's Lua API
# (`hl.plugin.hyprbars.add_button`), which
# exists only once the plugin is loaded. Home Manager loads plugin packages
# *after* the config is parsed — in the `hyprland.start` hook, as an async
# `hyprctl plugin load` — so we load the plugin ourselves at config-parse time
# with `hl.plugin.load(...)` (deterministic; this is what upstream HM later
# adopted). The buttons sit behind a nil-guard: the first parse schedules the
# load (guard false), then the reload that follows the load re-runs this block
# with the plugin present and actually registers the buttons.
#
# Button colours come from the active colourme scheme through the generated
# `theme.colourme` module (`failure`/`warning`/`success`, and `background` for
# the glyph); the `warning` key is defined in the hypr colourme template.
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
        -- Traffic-light colours from the active colourme scheme: red=failure,
        -- yellow=warning, green=success; the glyph uses the scheme background
        -- for contrast.
        local colours = require("theme.colourme")

        hl.config({
          plugin = {
            hyprbars = {
              bar_height = 28,
              bar_blur = true,
              bar_padding = ${toString t.space.sm},
              bar_button_padding = ${toString t.space.xs},
              bar_buttons_alignment = "left",
              icon_on_hover = true,
              -- Under the Lua config type, `hyprctl dispatch` is shorthand for
              -- `hl.dispatch(...)`, so legacy names (killactive/fullscreen/…)
              -- are invalid Lua and silently do nothing. Actions must use the
              -- Lua dispatch API.
              on_double_click = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ action = "toggle" })']],
            },
          },
        })

        hl.plugin.hyprbars.add_button({ bg_color = colours.failure, fg_color = colours.background, size = 10, icon = "x", action = [[hyprctl dispatch 'hl.dsp.window.close()']] })
        hl.plugin.hyprbars.add_button({ bg_color = colours.warning, fg_color = colours.background, size = 10, icon = "-", action = [[hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })']] })
        hl.plugin.hyprbars.add_button({ bg_color = colours.success, fg_color = colours.background, size = 10, icon = "+", action = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ action = "toggle" })']] })
      end
    '';
  };
}

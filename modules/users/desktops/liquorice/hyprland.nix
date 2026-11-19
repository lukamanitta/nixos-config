{
  config,
  lib,
  ...
}:

# LiquoRice's compositor look. Deliberately its own file rather than shared
# with LitheDE: D29 keeps the visual half per-DE so the two can diverge. Values
# start from the LitheDE tokens; they will be tuned for the pill's own geometry.
let
  enabled = config.my.desktops.environment == "liquorice";
  lua = lib.generators.mkLuaInline;
  activeBorder = lua ''
    (function()
      local ok, theme = pcall(require, "theme.colourme")
      return (ok and theme.activeBorderColor) or "rgb(555555)"
    end)()
  '';
in
{
  config = lib.mkIf enabled {
    wayland.windowManager.hyprland.settings.config = {
      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
        col.active_border = activeBorder;
      };

      decoration = {
        rounding = 10;
        rounding_power = 2;
        active_opacity = 1.0;
        inactive_opacity = 0.96;
        blur = {
          enabled = true;
          size = 6;
          passes = 2;
          vibrancy = 0.2;
        };
        shadow = {
          color = "rgba(15, 15, 15, 0.5)";
          color_inactive = "rgba(15, 15, 15, 0.3)";
          offset = [
            0
            4
          ];
          range = 24;
          render_power = 3;
        };
      };

      group.col.border_active = activeBorder;

      animations.enabled = true;
    };
  };
}

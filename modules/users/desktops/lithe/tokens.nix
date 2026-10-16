{ lib, ... }:

# LitheDE design tokens (docs/LITHEDE.md). Single source of truth consumed by
# the generated Hyprland config, the panel, and the colourme toolkit templates.
# Colours are *not* here — they come from the colourme runtime seam.
{
  options.my.desktops.lithe.tokens = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {
      radius = {
        window = 10;
        panel = 10;
        popover = 12;
        inner = 8; # panel radius − inset
      };
      space = {
        xs = 4;
        sm = 8;
        md = 12;
        lg = 16;
      };
      font = {
        ui = "SF Pro Text";
        mono = "SF Mono";
        glyph = "Symbols Nerd Font";
        size = {
          ui = 13;
          small = 11;
          large = 15;
          title = 17;
        };
      };
      opacity = {
        panel = 0.8;
        popover = 0.9;
        osd = 0.85;
        windowInactive = 0.96;
      };
      border = {
        active = 2;
        inactive = 1;
      };
      shadow = {
        range = 24;
        offset = [
          0
          4
        ];
        renderPower = 3;
        colorActive = "rgba(15, 15, 15, 0.5)";
        colorInactive = "rgba(15, 15, 15, 0.3)";
      };
      blur = {
        size = 6;
        passes = 2;
        vibrancy = 0.2;
      };
    };
    description = "LitheDE design tokens.";
  };
}

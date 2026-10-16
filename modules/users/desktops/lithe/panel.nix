{
  config,
  lib,
  pkgs,
  ...
}:

# LitheDE top bar (waybar): launcher + taskbar on the left, workspaces centred
# (the dock analogue), tray + clock + control-center on the right. Geometry
# comes from the LitheDE tokens; colours from the colourme waybar seam.
let
  enabled = config.my.desktops.environment == "lithe";
  t = config.my.desktops.lithe.tokens;
  launcher =
    if config.my.desktop.programs.launcher != null then
      config.my.desktop.programs.launcher
    else
      "hyprlauncher";

  barConfig = {
    layer = "top";
    position = "top";
    height = 34;
    spacing = t.space.sm;
    "modules-left" = [
      "custom/launcher"
      "wlr/taskbar"
    ];
    "modules-center" = [ "hyprland/workspaces" ];
    "modules-right" = [
      "tray"
      "clock"
      "custom/controlcenter"
    ];
    "custom/launcher" = {
      format = "Apps";
      tooltip = false;
      "on-click" = launcher;
    };
    "wlr/taskbar" = {
      format = "{icon}";
      "icon-size" = 18;
      "tooltip-format" = "{title}";
      "on-click" = "activate";
      "on-click-middle" = "close";
      "on-click-right" = "minimize";
    };
    "hyprland/workspaces" = {
      format = "{name}";
      "on-click" = "activate";
    };
    tray = {
      "icon-size" = 18;
      spacing = 8;
    };
    clock = {
      format = "{:%a %H:%M}";
      "tooltip-format" = "{:%A %d %B %Y}";
    };
    "custom/controlcenter" = {
      format = "⏻";
      tooltip = false;
      "on-click" = "swaync-client -t -sw";
    };
  };
in
{
  config = lib.mkIf enabled {
    xdg.configFile = {
      "waybar/config".source = (pkgs.formats.json { }).generate "waybar-config.json" barConfig;

      "waybar/style.css".text = ''
        @import url("colourme-waybar.css");

        * {
          font-family: "${t.font.ui}", "${t.font.glyph}";
          font-size: ${toString t.font.size.ui}px;
          border: none;
          border-radius: 0;
          min-height: 0;
          padding: 0 ${toString t.space.sm}px;
        }

        window#waybar {
          background: alpha(@colourme_bg, ${toString t.opacity.panel});
          color: @colourme_fg;
        }

        #workspaces button {
          color: @colourme_fg_dim;
          padding: 0 ${toString t.space.sm}px;
          background: transparent;
          border-radius: ${toString t.radius.inner}px;
        }

        #workspaces button.active {
          color: @colourme_bg;
          background: @colourme_accent;
        }

        #custom-launcher {
          color: @colourme_accent;
          font-weight: bold;
        }

        #taskbar button.active {
          background: alpha(@colourme_accent, 0.3);
          border-radius: ${toString t.radius.inner}px;
        }

        #tray,
        #custom-controlcenter {
          color: @colourme_fg;
        }
      '';
    };
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:

# LitheDE top bar (waybar): one fused strip (DECISIONS D33).
#
#   left   — launcher (magnifier) + dock of running windows
#   centre — workspace dots (occupied only, click to switch)
#   right  — tray + clock + control centre
#
# There is no separate taskbar next to a workspace row: the workspace module is
# reduced to status dots, and the dock is the only clickable window list.
# Geometry comes from the LitheDE tokens; colours from the colourme waybar seam.
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
      # Magnifier: the button opens hyprlauncher's search, it does not list apps.
      format = "";
      tooltip = false;
      "on-click" = launcher;
    };
    "wlr/taskbar" = {
      format = "{icon}";
      "icon-size" = 18;
      "tooltip-format" = "{title}";
      # Stable order with same-app windows adjacent; `active-first` would
      # reshuffle the row on every focus change.
      "sort-by-app-id" = true;
      "on-click" = "activate";
      "on-click-middle" = "close";
      "on-click-right" = "maximize";
    };
    "hyprland/workspaces" = {
      # Five fixed slots so a new workspace never shifts the row; empty ones
      # are just dim dots (D33).
      format = "{icon}";
      "format-icons" = {
        default = "●";
      };
      "persistent-workspaces" = {
        "*" = [
          1
          2
          3
          4
          5
        ];
      };
      "all-outputs" = false;
      "show-special" = false;
      tooltip = true;
      "tooltip-format" = "workspace {name}";
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
    # A switch replaces waybar's CSS on disk but nothing told the running bar;
    # reload it after the colourme files are seeded.
    home.activation.reloadWaybar =
      lib.hm.dag.entryAfter
        [
          "writeBoundary"
          "seedColourmeTheme"
        ]
        ''
          rm -f "$HOME/.config/waybar/lithede-state.css"
          if [ -e "$HOME/.config/waybar/colourme-waybar.css" ]; then
            pkill -SIGUSR2 -x waybar || true
          fi
        '';

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

        /* Workspace dots — small, tightly packed status pips. Occupied slots
           are lit; empty and not-yet-created ones stay dim; active is accent. */
        #workspaces button {
          color: alpha(@colourme_fg, 0.35);
          background: transparent;
          padding: 0 1px;
          margin: 0;
          min-width: 0;
          min-height: 0;
          font-size: 3px;
        }

        #workspaces button label {
          font-size: 3px;
        }

        #workspaces button.empty {
          color: alpha(@colourme_fg, 0.12);
        }

        #workspaces button.active {
          color: @colourme_accent;
        }

        #custom-launcher {
          color: @colourme_accent;
          font-weight: bold;
        }

        /* Dock: the focused window gets a straight 2px underline with rounded
           caps (bottom-corner radius clips the border ends), nothing tinted. */
        #taskbar button {
          background: transparent;
          padding: 0 ${toString t.space.xs}px;
          border-bottom: 2px solid transparent;
          border-radius: 0 0 2px 2px;
        }

        #taskbar button.active {
          border-bottom-color: @colourme_accent;
        }

        #tray,
        #custom-controlcenter {
          color: @colourme_fg;
        }
      '';
    };
  };
}

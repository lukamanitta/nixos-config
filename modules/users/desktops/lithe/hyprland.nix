{ config, lib, ... }:

# LitheDE's compositor look and animations. This is the *per-DE* half of the
# Hyprland config: the shared `hyprland` feature owns everything non-visual
# (input, misc, cursor, master, binds, monitors, rules, autostart), and this
# file owns `general`/`decoration`/`group` plus the animation list. Duplication
# across DEs is deliberate so each can diverge freely (docs/LITHEDE.md).
let
  t = config.my.desktops.lithe.tokens;
  lua = lib.generators.mkLuaInline;
  activeBorder = lua ''require("theme.colourme").activeBorderColor'';
  enabled = config.my.desktops.environment == "lithe";
in
{
  config = lib.mkIf enabled {
    wayland.windowManager.hyprland.settings = {
      config = {
        general = {
          gaps_in = t.space.xs;
          gaps_out = t.space.sm;
          border_size = t.border.active;
          resize_on_border = false;
          allow_tearing = false;
          layout = "dwindle";
          col.active_border = activeBorder;
        };

        decoration = {
          rounding = t.radius.window;
          rounding_power = 2;
          active_opacity = 1.0;
          inactive_opacity = t.opacity.windowInactive;
          blur = {
            enabled = true;
            size = t.blur.size;
            passes = t.blur.passes;
            vibrancy = t.blur.vibrancy;
          };
          shadow = {
            color = t.shadow.colorActive;
            color_inactive = t.shadow.colorInactive;
            offset = t.shadow.offset;
            range = t.shadow.range;
            render_power = t.shadow.renderPower;
          };
        };

        group.col.border_active = activeBorder;

        animations.enabled = true;
      };

      curve = [
        {
          _args = [
            "easeOutQuint"
            {
              type = "bezier";
              points = [
                [
                  0.23
                  1
                ]
                [
                  0.32
                  1
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "easeInOutCubic"
            {
              type = "bezier";
              points = [
                [
                  0.65
                  0.05
                ]
                [
                  0.36
                  1
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "linear"
            {
              type = "bezier";
              points = [
                [
                  0
                  0
                ]
                [
                  1
                  1
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "almostLinear"
            {
              type = "bezier";
              points = [
                [
                  0.5
                  0.5
                ]
                [
                  0.75
                  1
                ]
              ];
            }
          ];
        }
        {
          _args = [
            "quick"
            {
              type = "bezier";
              points = [
                [
                  0.15
                  0
                ]
                [
                  0.1
                  1
                ]
              ];
            }
          ];
        }
      ];

      animation = [
        {
          leaf = "global";
          enabled = true;
          speed = 10;
          bezier = "default";
        }
        {
          leaf = "border";
          enabled = true;
          speed = 5.39;
          bezier = "easeOutQuint";
        }
        {
          leaf = "windows";
          enabled = true;
          speed = 4.79;
          bezier = "easeOutQuint";
        }
        {
          leaf = "windowsIn";
          enabled = true;
          speed = 4.1;
          bezier = "easeOutQuint";
          style = "popin 87%";
        }
        {
          leaf = "windowsOut";
          enabled = true;
          speed = 1.49;
          bezier = "linear";
          style = "popin 87%";
        }
        {
          leaf = "fadeIn";
          enabled = true;
          speed = 1.73;
          bezier = "almostLinear";
        }
        {
          leaf = "fadeOut";
          enabled = true;
          speed = 1.46;
          bezier = "almostLinear";
        }
        {
          leaf = "fade";
          enabled = true;
          speed = 3.03;
          bezier = "quick";
        }
        {
          leaf = "layers";
          enabled = true;
          speed = 3.81;
          bezier = "easeOutQuint";
        }
        {
          leaf = "layersIn";
          enabled = true;
          speed = 4;
          bezier = "easeOutQuint";
          style = "fade";
        }
        {
          leaf = "layersOut";
          enabled = true;
          speed = 1.5;
          bezier = "linear";
          style = "fade";
        }
        {
          leaf = "fadeLayersIn";
          enabled = true;
          speed = 1.79;
          bezier = "almostLinear";
        }
        {
          leaf = "fadeLayersOut";
          enabled = true;
          speed = 1.39;
          bezier = "almostLinear";
        }
        {
          leaf = "workspaces";
          enabled = true;
          speed = 1.94;
          bezier = "almostLinear";
          style = "fade";
        }
        {
          leaf = "workspacesIn";
          enabled = true;
          speed = 1.21;
          bezier = "almostLinear";
          style = "fade";
        }
        {
          leaf = "workspacesOut";
          enabled = true;
          speed = 1.94;
          bezier = "almostLinear";
          style = "fade";
        }
        {
          leaf = "zoomFactor";
          enabled = true;
          speed = 7;
          bezier = "quick";
        }
      ];

      gesture = [
        {
          fingers = 3;
          direction = "horizontal";
          action = "workspace";
        }
      ];
    };
  };
}

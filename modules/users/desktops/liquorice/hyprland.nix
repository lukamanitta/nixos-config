{
  config,
  lib,
  ...
}:

# LiquoRice's compositor look. Deliberately its own file rather than shared
# with LitheDE: D29 keeps the visual half per-DE so the two can diverge.
#
# Values are ported 1:1 from the author's Arch dotfiles
# (`~/dotfiles/hypr/.config/hypr/modules/{config,animations}.lua`) so switching
# to NixOS feels identical: same gaps/rounding/blur/shadow and the same curve +
# animation list, plus the three-finger workspace gesture.
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
    wayland.windowManager.hyprland.settings = {
      config = {
        general = {
          gaps_in = 4;
          gaps_out = {
            top = 3;
            right = 8;
            bottom = 8;
            left = 8;
          };
          border_size = 2;
          resize_on_border = false;
          allow_tearing = false;
          layout = "dwindle";
          col.active_border = activeBorder;
        };

        decoration = {
          rounding = 8;
          rounding_power = 2;
          active_opacity = 1.0;
          inactive_opacity = 0.96;
          blur = {
            enabled = true;
            size = 3;
            passes = 1;
            vibrancy = 0.1696;
          };
          shadow = {
            color = "rgba(15, 15, 15, 0.6)";
            color_inactive = "rgba(15, 15, 15, 0.3)";
            offset = [
              2
              2
            ];
            range = 11;
            render_power = 2;
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

{ lib, pkgs, ... }:

{
  home.packages = [ pkgs.xdg-terminal-exec ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    configType = "lua";

    settings = {
      mod = {
        _var = "SUPER";
      };

      config = {
        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
        };
        decoration = {
          rounding = 8;
        };
        input = {
          kb_layout = "us";
          follow_mouse = 1;
        };
        misc = {
          disable_hyprland_logo = true;
        };
      };

      monitor = [
        {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = "auto";
        }
      ];

      bind = [
        {
          _args = [
            (lib.generators.mkLuaInline ''mod .. " + RETURN"'')
            (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("xdg-terminal-exec")'')
          ];
        }
        {
          _args = [
            (lib.generators.mkLuaInline ''mod .. " + Q"'')
            (lib.generators.mkLuaInline "hl.dsp.window.close()")
          ];
        }
      ];
    };
  };
}

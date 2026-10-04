{ pkgs, lib, ... }:

# Default provider of the "usable DE" roles. Imported by the hyprland feature,
# so `hyprland` alone yields a working desktop; override or drop per host/user.
{
  home.packages = with pkgs; [
    hyprlauncher
    hyprlock
    hypridle
    hyprpaper
    waybar
  ];

  my.desktop = {
    programs.launcher = lib.mkDefault "hyprlauncher";
    programs.lock = lib.mkDefault "hyprlock";
    services.idle = lib.mkDefault "hypridle";
    services.wallpaper = lib.mkDefault "hyprpaper";
    services.statusBar = lib.mkDefault "waybar";
  };

  xdg.configFile = {
    "hypr/hypridle.conf".text = ''
      general {
          lock_cmd = pidof hyprlock || hyprlock
          before_sleep_cmd = loginctl lock-session
      }

      listener {
          timeout = 300
          on-timeout = loginctl lock-session
      }
    '';

    "hypr/hyprpaper.conf".text = ''
      splash = false
    '';

    "hypr/hyprlock.conf".text = ''
      background {
          color = rgba(1a1b2aff)
      }

      input-field {
          size = 200, 50
          outline_thickness = 3
      }
    '';

    "waybar/config".text = ''
      {
        "layer": "top",
        "modules-left": [ "hyprland/workspaces" ],
        "modules-center": [ "hyprland/window" ],
        "modules-right": [ "clock" ],
        "clock": { "format": "{:%H:%M}" }
      }
    '';

    "waybar/style.css".text = ''
      * {
        font-family: monospace;
        font-size: 13px;
      }

      window#waybar {
        background: rgba(26, 27, 42, 0.9);
        color: #828bb8;
      }
    '';
  };
}

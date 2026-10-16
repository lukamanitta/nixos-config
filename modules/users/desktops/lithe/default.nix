{
  config,
  lib,
  pkgs,
  ...
}:

# LitheDE — the default, out-of-the-box desktop environment (docs/LITHEDE.md).
# Everything is gated on `my.desktops.environment == "lithe"`, so a peer DE can
# replace it wholesale without forks or `mkForce`.
let
  enabled = config.my.desktops.environment == "lithe";

  lua = lib.generators.mkLuaInline;
  toLua = lib.generators.toLua { };
  exec = cmd: lua "hl.dsp.exec_cmd(${toLua cmd})";
  bind = key: cmd: {
    _args = [
      (key)
      (exec cmd)
    ];
  };

  # Shared clipboard history; the picker routes through hyprlauncher's dmenu
  # mode (no wofi). See docs/LITHEDE.md.
  cliphist-watch = pkgs.writeShellApplication {
    name = "cliphist-watch";
    runtimeInputs = with pkgs; [
      cliphist
      wl-clipboard
    ];
    text = ''
      wl-paste --type text --watch cliphist store &
      wl-paste --type image --watch cliphist store &
      wait
    '';
  };

  cliphist-pick = pkgs.writeShellApplication {
    name = "cliphist-pick";
    runtimeInputs = with pkgs; [
      cliphist
      wl-clipboard
      hyprlauncher
    ];
    text = ''
      cliphist list | hyprlauncher --dmenu | cliphist decode | wl-copy
    '';
  };
in
{
  imports = [
    ../default.nix
    ./tokens.nix
    ./hyprland.nix
    ./toolkit.nix
    ./panel.nix
    ./controlcenter.nix
    ./windowcontrols.nix
  ];

  config = lib.mkIf enabled {
    home.packages = with pkgs; [
      hyprlauncher
      hyprlock
      hypridle
      hyprpaper
      waybar
      swaynotificationcenter
      swayosd
      thunar
      hyprshot
      cliphist
      wl-clipboard
      networkmanagerapplet
      cliphist-watch
      cliphist-pick
    ];

    my.desktop = {
      programs = {
        launcher = lib.mkDefault "hyprlauncher";
        lock = lib.mkDefault "hyprlock";
        fileExplorer = lib.mkDefault "thunar";
        clipboardPicker = lib.mkDefault "cliphist-pick";
      };
      services = {
        idle = lib.mkDefault "hypridle";
        notification = lib.mkDefault "swaync";
        osd = lib.mkDefault "swayosd-server";
        wallpaper = lib.mkDefault "hyprpaper";
        statusBar = lib.mkDefault "waybar";
        clipboardWatcher = lib.mkDefault "cliphist-watch";
      };
    };

    # Network applet lives in the bar tray.
    my.hyprland.autostart = lib.mkAfter [ "nm-applet --indicator" ];

    wayland.windowManager.hyprland.settings.bind = [
      (bind (lua ''"PRINT"'') "hyprshot -m region --clipboard-only")
      (bind (lua ''mod .. " + SHIFT + S"'') "hyprshot -m region --clipboard-only")
      (bind (lua ''mod .. " + SHIFT + Print"'') "hyprshot -m window --clipboard-only")
    ];

    xdg.configFile = {
      "hypr/hypridle.conf".text = ''
        general {
            lock_cmd = pidof hyprlock || hyprlock
            before_sleep_cmd = loginctl lock-session
        }

        listener {
            timeout = 500
            on-timeout = notify-send "You are idle!"
            on-resume = notify-send "Welcome back!"
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
    };
  };
}

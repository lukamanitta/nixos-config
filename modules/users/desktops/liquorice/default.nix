{
  config,
  lib,
  pkgs,
  ...
}:

# LiquoRice — the personal Quickshell desktop environment (docs/LITHEDE.md).
# A peer of LitheDE over the shared compositor, selected with
# `my.desktops.environment = "liquorice"`.
#
# The QML lives out-of-store in `configs/quickshell` so it stays editable on the
# live machine (D25). The shell hard-codes
# `$HOME/.config/hypr/scripts/{open-pill-surface,lock,cliphist-thumbs}.sh`, so
# those scripts are symlinked there from `configs/hypr/scripts` — edit them in
# the repo, no rebuild needed.
let
  enabled = config.my.desktops.environment == "liquorice";
  home = config.home.homeDirectory;
  outOfStore = config.lib.file.mkOutOfStoreSymlink;
  lua = lib.generators.mkLuaInline;
  toLua = lib.generators.toLua { };
  exec = cmd: lua "hl.dsp.exec_cmd(${toLua cmd})";
  bind = key: cmd: {
    _args = [
      (lua ''mod .. " + ${key}"'')
      (exec cmd)
    ];
  };

  # Stored here rather than shared because LitheDE defines its own copy; lift
  # into features/desktop once a second consumer needs edits.
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

  scripts = "$HOME/.config/hypr/scripts";
in
{
  imports = [
    ../default.nix
    ./hyprland.nix
  ];

  config = lib.mkIf enabled {
    programs.quickshell.enable = true;

    home.packages = with pkgs; [
      # Pill surface dependencies (Quickshell.Io.Process commands).
      cliphist
      wl-clipboard
      jq
      imagemagick
      ddcutil
      brightnessctl
      networkmanager
      bluez
      libnotify
      curl
      playerctl
      # Screenshots used by the shared binds.
      hyprshot
      grim
      slurp
      # Providers the shared compositor role defaults used to get from LitheDE.
      hyprpaper
      whitesur-cursors
      hypridle
      yazi
      cliphist-watch
    ];

    xdg.configFile = {
      "quickshell".source = outOfStore "${home}/nixos-config/configs/quickshell";
      "hypr/scripts".source = outOfStore "${home}/nixos-config/configs/hypr/scripts";

      "hypr/hyprpaper.conf".text = ''
        splash = false
      '';

      "hypr/hypridle.conf".text = ''
        general {
            lock_cmd = ${scripts}/lock.sh
            before_sleep_cmd = ${scripts}/lock.sh
        }

        listener {
            timeout = 300
            on-timeout = ${scripts}/lock.sh
        }
      '';
    };

    my.desktop.programs = {
      launcher = lib.mkDefault "${scripts}/open-pill-surface.sh launcher";
      clipboardPicker = lib.mkDefault "${scripts}/open-pill-surface.sh clipboard";
      lock = lib.mkDefault "${scripts}/lock.sh";
      fileExplorer = lib.mkDefault "ghostty -e yazi";
    };

    # Hyprland's built-in cursor is the blue one; use the WhiteSur cursors that
    # match the rest of the shell. XCURSOR_THEME is what Hyprland falls back to
    # when the hyprcursor theme is absent.
    home.pointerCursor = {
      name = "WhiteSur-cursors";
      package = pkgs.whitesur-cursors;
      size = 24;
      gtk.enable = true;
    };

    wayland.windowManager.hyprland.settings.env = [
      {
        _args = [
          "XCURSOR_THEME"
          "WhiteSur-cursors"
        ];
      }
    ];

    my.desktop.services = {
      statusBar = lib.mkDefault "quickshell -n -d";
      wallpaper = lib.mkDefault "hyprpaper";
      # hypridle is disabled for now; set `idle = lib.mkDefault "hypridle";`
      # to bring the idle/lock timer back.
      clipboardWatcher = lib.mkDefault "${lib.getExe cliphist-watch}";
      # Notifications and the transient OSD are provided by the pill itself,
      # so `services.notification` / `services.osd` stay null.
    };

    # Pill surfaces that are not part of the shared role interface.
    wayland.windowManager.hyprland.settings.bind = [
      (bind "M" "${scripts}/open-pill-surface.sh media")
      (bind "P" "${scripts}/open-pill-surface.sh keyboard")
    ];
  };
}

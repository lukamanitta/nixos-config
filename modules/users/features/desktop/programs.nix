{ lib, ... }:

# Compositor-agnostic program/service roles. Providers (features) set these;
# consumers (binds, autostart, other desktops) read them.
{
  options.my.desktop = {
    programs = {
      terminal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Terminal emulator command.";
      };
      fileExplorer = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "File manager command.";
      };
      browser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Web browser command.";
      };
      launcher = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Application launcher command.";
      };
      clipboardPicker = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Clipboard history picker command.";
      };
      lock = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Screen locker command (lock now).";
      };
    };

    services = {
      statusBar = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Status bar command started at session start.";
      };
      idle = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Idle management daemon command.";
      };
      wallpaper = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Wallpaper daemon command.";
      };
      clipboardWatcher = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Clipboard history watcher command.";
      };
    };
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:

# Google Drive as an on-demand FUSE mount. The OAuth config stays in
# ~/.config/rclone/rclone.conf (never in the store); copy it from the old
# machine with `rclone config`.
let
  cfg = config.my.gdrive;

  offlineDir = "${config.home.homeDirectory}/GoogleDrive-offline";
in
{
  options.my.gdrive = {
    enable = lib.mkEnableOption "the rclone Google Drive mount";

    remote = lib.mkOption {
      type = lib.types.str;
      default = "gdrive";
      description = "rclone remote name from rclone.conf.";
    };

    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/mnt/gdrive";
      description = "Where the Drive tree is mounted.";
    };

    cacheSize = lib.mkOption {
      type = lib.types.str;
      default = "30G";
      description = "rclone VFS cache ceiling (e.g. 30G).";
    };

    cacheAge = lib.mkOption {
      type = lib.types.str;
      default = "720h";
      description = "How long cached files stay before eviction.";
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments appended to `rclone mount`.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.rclone
      pkgs.fuse3
      (pkgs.writeShellScriptBin "gdrive-pin" ''
        set -euo pipefail
        if [ "$#" -ne 1 ]; then
          echo "usage: gdrive-pin <path-inside-drive>" >&2
          exit 1
        fi
        mkdir -p ${lib.escapeShellArg offlineDir}
        exec ${pkgs.rclone}/bin/rclone copy \
          "${cfg.remote}:$1" ${lib.escapeShellArg "${offlineDir}/$1"} \
          --progress
      '')
    ];

    systemd.user.services.rclone-gdrive = {
      Unit = {
        Description = "rclone Google Drive mount";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "notify";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg cfg.mountPoint}";
        ExecStart = lib.escapeShellArgs (
          [
            "${pkgs.rclone}/bin/rclone"
            "mount"
            "${cfg.remote}:"
            cfg.mountPoint
            "--vfs-cache-mode"
            "full"
            "--vfs-cache-max-size"
            cfg.cacheSize
            "--vfs-cache-max-age"
            cfg.cacheAge
            "--dir-cache-time"
            "1h"
            "--vfs-read-ahead"
            "128M"
            "--buffer-size"
            "32M"
            "--drive-chunk-size"
            "64M"
            "--transfers"
            "4"
            "--checkers"
            "8"
          ]
          ++ cfg.extraFlags
        );
        ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u ${lib.escapeShellArg cfg.mountPoint}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}

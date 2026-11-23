{
  config,
  lib,
  pkgs,
  ...
}:

# OpenRGB server as the user. The NixOS module still provides the udev rules,
# i2c modules and package; its root service is disabled by the host because
# the user service needs the profiles from ~/.config/OpenRGB (the same place
# the GUI and colourme use).
let
  cfg = config.my.openrgb;
in
{
  options.my.openrgb = {
    enable = lib.mkEnableOption "the user OpenRGB SDK server";

    profile = lib.mkOption {
      type = lib.types.str;
      default = "true-white";
      description = "Profile loaded when the server starts.";
    };

    serverPort = lib.mkOption {
      type = lib.types.port;
      default = 6742;
      description = "OpenRGB SDK server port.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.openrgb ];

    home.file.".config/OpenRGB/profiles/true-white.json".source =
      ../../hosts/luka-workstation/files/openrgb/profiles/true-white.json;
    home.file.".config/OpenRGB/profiles/Off.json".source =
      ../../hosts/luka-workstation/files/openrgb/profiles/Off.json;

    systemd.user.services.openrgb = {
      Unit = {
        Description = "OpenRGB SDK server";
        After = [ "network.target" ];
      };
      Service = {
        ExecStart = "${pkgs.openrgb}/bin/openrgb --server --server-port ${toString cfg.serverPort} --profile ${cfg.profile}";
        Restart = "always";
        RestartSec = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}

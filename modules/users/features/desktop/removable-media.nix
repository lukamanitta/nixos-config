{ pkgs, lib, config, ... }:

# Removable-media automounter (udiskie). Compositor-agnostic: it provides the
# `services.removableMedia` role, which the hyprland feature starts at session
# start. Its browse/terminal actions follow the `fileExplorer`/`terminal`
# program roles (DECISIONS D3, D28), so swapping either provider carries over.
let
  p = config.my.desktop.programs;

  programOptions =
    {
      automount = true;
      notify = true;
      tray = false;
    }
    // lib.optionalAttrs (p.fileExplorer != null) {
      file_manager = p.fileExplorer;
    }
    // lib.optionalAttrs (p.terminal != null) {
      terminal = p.terminal;
    };

  settings = {
    program_options = programOptions;
    notifications = {
      timeout = 2;
      device_added = false;
      device_removed = false;
      job_failed = -1;
    };
  };
in
{
  my.desktop.services.removableMedia = lib.mkDefault "udiskie";

  home.packages = [ pkgs.udiskie ];

  xdg.configFile."udiskie/config.yml".source =
    (pkgs.formats.yaml { }).generate "udiskie-config.yml" settings;
}

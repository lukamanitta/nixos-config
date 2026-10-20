{ config, ... }:

let
  # Static, non-host-varying config: stays in its native language under
  # configs/ and is symlinked out-of-store so it remains editable live (D25).
  # Assumes the flake is checked out at ~/nixos-config (see docs/INSTALL.md).
  configDir = "${config.home.homeDirectory}/nixos-config/configs/opencode";
in
{
  programs.opencode.enable = true;

  xdg.configFile = {
    "opencode/opencode.jsonc".source =
      config.lib.file.mkOutOfStoreSymlink "${configDir}/opencode.jsonc";
    "opencode/cli.json".source = config.lib.file.mkOutOfStoreSymlink "${configDir}/cli.json";
    "opencode/skills".source = config.lib.file.mkOutOfStoreSymlink "${configDir}/skills";
    "opencode/commands".source = config.lib.file.mkOutOfStoreSymlink "${configDir}/commands";
  };
}

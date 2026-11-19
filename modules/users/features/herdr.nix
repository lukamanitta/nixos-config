{
  config,
  lib,
  pkgs,
  ...
}:

# Herdr — terminal workspace manager (replaces tmux for now). The config is
# ported from the dotfiles and symlinked out-of-store (D25).
let
  herdr = pkgs.callPackage ../../../packages/herdr { };
in
{
  home.packages = [ herdr ];

  xdg.configFile."herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/configs/herdr/config.toml";

  # Ghostty auto-attach target. `mkDefault` so that importing the tmux feature
  # as well makes tmux win (it sets the option at normal priority).
  my.desktop.programs.multiplexer = lib.mkDefault "${herdr}/bin/herdr";
}

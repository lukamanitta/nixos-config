{ pkgs, config, ... }:

{
  home.packages = [ pkgs.tmux ];

  # Static, non-host-varying config: stays in its native language under
  # configs/ and is symlinked out-of-store so it remains editable live.
  # Assumes the flake is checked out at ~/nixos-config (see docs/INSTALL.md).
  xdg.configFile."tmux/tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nixos-config/configs/tmux/tmux.conf";
}

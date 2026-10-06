{ pkgs, lib, config, ... }:

{
  home.packages = [ pkgs.tmux ];

  # Static, non-host-varying config: stays in its native language under
  # configs/ and is symlinked out-of-store so it remains editable live.
  # Assumes the flake is checked out at ~/nixos-config (see docs/INSTALL.md).
  xdg.configFile."tmux/tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nixos-config/configs/tmux/tmux.conf";

  # Auto-attach tmux when a ghostty surface opens, but only when ghostty is
  # the configured terminal (i.e. the ghostty feature is in play). tmux
  # contributes this directly to ghostty's config (DECISIONS D9).
  xdg.configFile."ghostty/config".text =
    lib.mkIf (config.my.desktop.programs.terminal == "ghostty")
      (lib.mkAfter ''
        command = $SHELL -c "tmux new-session -A -s main"
      '');
}

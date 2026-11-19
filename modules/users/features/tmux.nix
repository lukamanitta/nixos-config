{
  pkgs,
  lib,
  config,
  ...
}:

let
  # Ghostty's `command` takes a path with no arguments, so tmux gets a wrapper.
  tmuxAttach = pkgs.writeShellApplication {
    name = "tmux-attach";
    runtimeInputs = [ pkgs.tmux ];
    text = ''
      exec tmux new-session -A -s main
    '';
  };
in
{
  home.packages = [ pkgs.tmux ];

  # Static, non-host-varying config: stays in its native language under
  # configs/ and is symlinked out-of-store so it remains editable live.
  # Assumes the flake is checked out at ~/nixos-config (see docs/INSTALL.md).
  xdg.configFile."tmux/tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/configs/tmux/tmux.conf";

  # Normal priority: when the herdr feature is also imported it sets the same
  # option with `mkDefault`, so tmux wins (DECISIONS D9).
  my.desktop.programs.multiplexer = "${tmuxAttach}/bin/tmux-attach";
}

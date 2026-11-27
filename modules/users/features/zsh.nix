{ config, lib, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases.lg = "lazygit";

    # Console autologin (workstation): getty starts a login shell on tty1 and
    # this execs the compositor, so logout falls back to getty and immediately
    # returns to the Quickshell lock screen. Other TTYs and SSH get a shell.
    profileExtra = lib.mkIf config.my.desktops.autologin ''
      if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
        exec start-hyprland
      fi
    '';

    initContent = ''
      bindkey '^F' autosuggest-accept

      # Typing a bare directory name (notably `..`) cds into it instead of
      # trying to execute it.
      setopt auto_cd
    '';
  };

  programs.starship.enable = true;

  programs.zoxide.enable = true;

  # Static, non-host-varying config: stays in its native language under
  # configs/ and is symlinked out-of-store so it remains editable live (D25).
  # Assumes the flake is checked out at ~/nixos-config (see docs/INSTALL.md).
  xdg.configFile."starship.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/configs/starship/starship.toml";
}

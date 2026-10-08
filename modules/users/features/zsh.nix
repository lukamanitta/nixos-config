{ config, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };

  programs.starship.enable = true;

  programs.zoxide.enable = true;

  # Static, non-host-varying config: stays in its native language under
  # configs/ and is symlinked out-of-store so it remains editable live (D25).
  # Assumes the flake is checked out at ~/nixos-config (see docs/INSTALL.md).
  xdg.configFile."starship.toml".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/nixos-config/configs/starship/starship.toml";
}

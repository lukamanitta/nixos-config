{ ... }:

{
  imports = [
    ../features/shell.nix
    ../features/cli-tools.nix
    ../features/git.nix
    ../features/neovim.nix
    ../features/opencode.nix
    ../features/hyprland.nix
  ];

  home.username = "luka";
  home.homeDirectory = "/home/luka";
  home.stateVersion = "26.05";
}

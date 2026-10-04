{ ... }:

{
  imports = [
    ../features/desktop/programs.nix
    ../features/shell.nix
    ../features/cli-tools.nix
    ../features/git.nix
    ../features/gh.nix
    ../features/neovim.nix
    ../features/opencode.nix
    ../features/hyprland
    ../features/ghostty.nix
  ];

  home.username = "luka";
  home.homeDirectory = "/home/luka";
  home.stateVersion = "26.05";
}

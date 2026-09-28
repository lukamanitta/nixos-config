{ ... }:

{
  imports = [
    ../modules/shell.nix
    ../modules/cli-tools.nix
    ../modules/git.nix
    ../modules/neovim.nix
    ../modules/opencode.nix
  ];

  home.username = "luka";
  home.homeDirectory = "/home/luka";
  home.stateVersion = "26.05";
}

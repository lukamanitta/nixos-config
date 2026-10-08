{ ... }:

{
  imports = [
    ../features/desktop/programs.nix
    ../features/shell.nix
    ../features/zsh.nix
    ../features/cli-tools.nix
    ../features/git.nix
    ../features/gh.nix
    ../features/neovim.nix
    ../features/opencode.nix
    ../features/hyprland
    ../features/ghostty.nix
    ../features/tmux.nix
    ../features/zen-browser.nix
  ];

  home.username = "luka";
  home.homeDirectory = "/home/luka";
  home.stateVersion = "26.05";
}

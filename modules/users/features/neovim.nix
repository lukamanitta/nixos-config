{
  config,
  pkgs,
  inputs,
  ...
}:

{
  # The config is the modular vim.pack setup from the dotfiles. It stays
  # out-of-store (D25) so plugin specs and keymaps are editable live; plugins
  # and LSP servers are installed by vim.pack/Mason at runtime.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/configs/nvim";

  home.packages = [
    inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default

    # External commands the config and its plugins shell out to.
    pkgs.ripgrep # telescope live_grep and friends
    pkgs.fd # file finding
    pkgs.fzf # fzf-lua/blink fuzzy matching
    pkgs.tree-sitter # nvim-treesitter parser builds
    pkgs.gcc # treesitter + telescope-fzf-native builds
    pkgs.gnumake # telescope-fzf-native build
    pkgs.nodejs # npm-based LSP servers installed by Mason
    pkgs.python3 # python-based Mason servers
  ];
}

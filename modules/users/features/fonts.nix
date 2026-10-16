{ config, lib, ... }:

# Vendored fonts (this repo's `fonts/`). Symlinked out-of-store into
# ~/.local/share/fonts, so the ~134 MB never enters the Nix store and the files
# stay editable. Shared by every DE; which face a given DE *uses* is a per-DE
# token. See docs/LITHEDE.md. NB: the previous blanket
# `~/.local/share/fonts -> ~/dotfiles/fonts` stow symlink must be removed so
# Nix can own the directory (stow -D fonts).
let
  families = [
    "SF-Pro"
    "SF-Mono"
    "SymbolsNerdFont"
    "Roboto"
    "Inter"
    "Ubuntu"
  ];

  link = family: {
    name = ".local/share/fonts/${family}";
    value.source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/fonts/${family}";
  };
in
{
  home.file = builtins.listToAttrs (map link families);

  fonts.fontconfig.enable = true;
}

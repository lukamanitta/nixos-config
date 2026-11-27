{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Australia/Brisbane";
  i18n.defaultLocale = "en_AU.UTF-8";

  environment.systemPackages = with pkgs; [
    vim
  ];

  environment.variables.EDITOR = "vim";

  # Mason installs upstream release binaries (lua-language-server,
  # rust-analyzer, ...) linked against the generic GNU loader at
  # /lib64/ld-linux-x86-64.so.2, which NixOS lacks. nix-ld provides the shim;
  # the servers only need glibc itself, which it supplies by default.
  programs.nix-ld.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}

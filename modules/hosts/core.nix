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

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}

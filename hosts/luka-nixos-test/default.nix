{ inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system/core.nix
  ];

  networking.hostName = "luka-nixos-test";
  networking.networkmanager.enable = true;

  services.xserver.xkb.layout = "us";
  services.xserver.xkb.variant = "";

  users.users.luka = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;

    users.luka = {
      imports = [ ../../home-manager/default.nix ];
    };
  };

  services.openssh.enable = true;

  system.stateVersion = "26.05";
}

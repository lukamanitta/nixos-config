{ inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../core.nix
    ../features/desktop/hyprland.nix
    ../../users/luka/system.nix
  ];

  networking.hostName = "luka-nixos-test";
  networking.networkmanager.enable = true;

  services.xserver.xkb.layout = "us";
  services.xserver.xkb.variant = "";

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;

    users.luka = {
      imports = [ ../../users/luka/home.nix ];
    };
  };

  services.openssh.enable = true;

  system.stateVersion = "26.05";
}

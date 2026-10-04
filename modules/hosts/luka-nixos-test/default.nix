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
  console.useXkbConfig = true;

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;

    users.luka = {
      imports = [ ../../users/luka/home.nix ];

      my.hyprland = {
        monitors = [
          {
            output = "";
            mode = "preferred";
            position = "auto";
            scale = "1";
          }
        ];
        workspaceRules = [ ];
      };
    };
  };

  services.openssh.enable = true;

  system.stateVersion = "26.05";
}

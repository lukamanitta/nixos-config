{ inputs, pkgs, ... }:

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

      # hyprlauncher segfaults in QEMU (aquamarine picks a DRM node with no
      # render node); use fuzzel (wl_shm-based) on the test VM only.
      home.packages = [ pkgs.fuzzel ];
      my.desktop.programs.launcher = "fuzzel";

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

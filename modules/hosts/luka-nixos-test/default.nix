{ inputs, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../core.nix
    ../features/hyprland.nix
    ../features/desktop
    ../../users/luka/system.nix
    inputs.msi-nix.nixosModules.default
  ];

  # Disposable test VM: agent access over SSH needs unattended sudo, and the
  # remote store must accept unsigned paths copied from the workstation.
  security.sudo.wheelNeedsPassword = false;
  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  # Docker (Mongo container), *.test hosts, and :443 for Caddy.
  services.msi = {
    enable = true;
    dockerUsers = [ "luka" ];
  };

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

      # LiquoRice is the track we are bringing up; flip back to "lithe" to
      # compare. hyprlauncher's QEMU crash no longer applies, so the host-level
      # launcher override is gone; fuzzel stays installed as a fallback.
      my.desktops.environment = "liquorice";
      programs.msi.enable = true;
      home.packages = [ pkgs.fuzzel ];

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

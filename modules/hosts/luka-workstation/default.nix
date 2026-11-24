{
  inputs,
  lib,
  pkgs,
  ...
}:

# Personal workstation: Ryzen 9800X3D, RX 9070 XT, Gigabyte B850M.
# Dual-boots with Arch while NixOS is proven; after that Arch is replaced.
{
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ../core.nix
    ../features/hyprland.nix
    ../features/desktop
    ../features/creative.nix
    ../../users/luka/system.nix
    inputs.msi-nix.nixosModules.default
    inputs.coolercontrol.nixosModules.default
  ];

  networking.hostName = "luka-workstation";
  networking.networkmanager.enable = true;

  services.xserver.xkb.layout = "us";
  console.useXkbConfig = true;

  # Docker (Mongo container for the MSI stack), *.test hosts, and :443.
  services.msi = {
    enable = true;
    dockerUsers = [ "luka" ];
  };

  # Tailscale is a must-have; authentication is manual (`tailscale up`).
  services.tailscale.enable = true;

  # OpenRGB: server owns the profile, GUI can still connect. RAM detection is
  # known to be flaky; it is deliberately not retried for now.
  nixpkgs.overlays = [
    inputs.coolercontrol.overlays.default
  ];

  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
  };

  # The module's root service cannot see the user's ~/.config/OpenRGB profiles,
  # so the user service in modules/users/features/openrgb.nix owns the server.
  systemd.services.openrgb.wantedBy = lib.mkForce [ ];
  users.groups.i2c = { };
  users.users.luka.extraGroups = [ "i2c" ];

  # CoolerControl 5.x from the flake. The config is a seed: the daemon owns
  # /var/lib/coolercontrol/config.toml after the first start.
  programs.coolercontrol = {
    enable = true;
    configFile = ./files/coolercontrol/config.toml;
  };

  systemd.tmpfiles.rules = [
    "C /var/lib/coolercontrol/overrides.toml 0644 root root - ${./files/coolercontrol/overrides.toml}"
  ];

  # Bluetooth (RTL8852CE combo).
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Windows is on a separate ESP; systemd-boot needs the EDK2 shell handle.
  # Run `map -c` in the EDK2 shell and replace FS1 with the Windows ESP.
  boot.loader.systemd-boot.edk2-uefi-shell.enable = true;
  boot.loader.systemd-boot.windows."Windows" = {
    title = "Windows";
    efiDeviceHandle = "FS0";
    sortKey = "z_windows";
  };
  boot.loader.systemd-boot.configurationLimit = 10;

  # Keep the clock in local time for the Windows dual-boot phase.
  time.hardwareClockInLocalTime = true;

  # Affinity's flake has a public binary cache; avoids rebuilding Wine/prefix.
  nix.settings = {
    extra-substituters = [ "https://cache.forall.systems" ];
    extra-trusted-public-keys = [
      "cache.forall.systems:5PmD7QO4MSF8YgyRZtkSGXRDo96H3bybIf2SsQh8ScI="
    ];
  };

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;

    users.luka = {
      imports = [
        ../../users/luka/home.nix
        ../../users/features/gdrive.nix
        ../../users/features/openrgb.nix
      ];

      # LitheDE is the stable desktop; switch to "liquorice" when desired.
      my.desktops.environment = "lithe";

      programs.msi = {
        enable = true;
        systemd.enable = true;
      };

      my.gdrive.enable = true;
      my.openrgb.enable = true;

      my.hyprland = {
        monitors = [
          {
            output = "DP-2";
            mode = "preferred";
            position = "0x0";
            scale = "1";
          }
          {
            output = "HDMI-A-2";
            mode = "preferred";
            position = "0x1080";
            scale = "1";
          }
        ];
        workspaceRules = [ ];
      };
    };
  };

  system.stateVersion = "26.05";
}

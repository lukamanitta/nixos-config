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
    # The MSI repos' helper scripts use `#!/bin/bash`; NixOS only ships
    # /bin/sh, so Ruby's Open3 fails to exec them with ENOENT.
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
  ];

  # Bluetooth (RTL8852CE combo).
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Windows is on a separate ESP; systemd-boot needs the EDK2 shell handle.
  # Find it with `map -r` in the EDK2 shell (currently FS0, found 2026-11-24).
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

      # LiquoRice (Quickshell) is the desktop; flip to "lithe" to fall back to
      # the stable LitheDE while bringing a change up.
      my.desktops.environment = "liquorice";

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
            mode = "highrr";
            position = "0x0";
            scale = "1";
          }
          {
            # The ARZOPA drops its HDMI signal intermittently at 144 Hz and
            # 120 Hz (the host logs nothing — the sink loses sync). 265.75 MHz
            # is stable. See docs/WORKSTATION-TROUBLESHOOTING.md, "ARZOPA HDMI
            # signal drops". Monitor-specific: drop the modeline if the
            # display is replaced.
            output = "HDMI-A-2";
            mode = "modeline 265.75 1920 1968 2000 2080 1080 1083 1088 1111 +hsync +vsync";
            position = "0x1080";
            scale = "1";
          }
        ];
        # Persistent per-monitor workspaces, matching the Arch dotfiles:
        # odd numbers on DP-2, even numbers on HDMI-A-2.
        workspaceRules =
          map (ws: {
            workspace = ws;
            monitor = "DP-2";
            persistent = true;
          }) [ "1" "3" "5" "7" "9" ]
          ++ map (ws: {
            workspace = ws;
            monitor = "HDMI-A-2";
            persistent = true;
          }) [ "2" "4" "6" "8" "10" ];
      };
    };
  };

  system.stateVersion = "26.05";
}

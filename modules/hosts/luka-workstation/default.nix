{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Helper for the activation hook below: writes Limine's remembered-entry EFI
  # variable. The vendor GUID is the one in Limine 12.5.2
  # (513ee0d0-6e43-cb05-b272-f146a2fcb88a); the v12.x source tree carries an
  # older value, so this was verified against the running firmware.
  limineLastBooted = pkgs.writeText "limine-last-booted.py" ''
    import os
    import struct
    import subprocess
    import sys

    distro, gen = sys.argv[1], sys.argv[2]
    path = "/sys/firmware/efi/efivars/LimineLastBootedEntry-513ee0d0-6e43-cb05-b272-f146a2fcb88a"
    # Limine's entry path has no leading slash for a top-level menu entry.
    entry = f"{distro} default profile/Generation {gen}"

    chattr = os.environ["CHATTR"]
    subprocess.run([chattr, "-i", path], stderr=subprocess.DEVNULL)
    try:
        os.remove(path)
    except FileNotFoundError:
        pass

    with open(path, "wb") as f:
        f.write(struct.pack("<I", 7))  # NV | BOOTSERVICE | RUNTIME
        # Limine stores the entry path as a NUL-terminated narrow string, not
        # UTF-16. Verified against the variable written by Limine 12.5.2.
        f.write(entry.encode("utf-8") + b"\0")

    subprocess.run([chattr, "+i", path], stderr=subprocess.DEVNULL)
  '';

  # Limine draws its menu on the framebuffer; cover the 16:9 panel with the
  # 3:2 source (scale to fill, crop the overflow) so there are no black bars.
  # The menu itself is a white-on-black panel below.
  limineWallpaper = pkgs.runCommand "limine-wallpaper.jpg" {
    nativeBuildInputs = [ pkgs.imagemagick ];
  } ''
    convert ${./files/limine/mac-1.jpg} \
      -resize 1920x1080^ -gravity center -extent 1920x1080 \
      -quality 92 "$out"
  '';
in

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

  # Limine owns the ESP. Secure Boot is enforced by enrolling a hash of
  # limine.conf into the signed Limine binary; the Microsoft and firmware
  # built-in keys stay enrolled so Windows, the GPU option ROMs and firmware
  # updates keep loading. See docs/WORKSTATION.md and DECISIONS D53.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.timeout = 10;
  boot.loader.limine = {
    enable = true;
    maxGenerations = 5;
    enableEditor = false;

    secureBoot = {
      enable = true;
      autoGenerateKeys = true;
      autoEnrollKeys = {
        enable = true;
        extraArgs = [
          "--microsoft"
          "--firmware-builtin"
        ];
      };
    };

    # Monochrome and minimal: one black-and-white photo, a white-on-black menu
    # panel, no branding and no colour accents. Keep this static — Limine's
    # config is hashed into the signed binary, so a runtime theme would still
    # need a rebuild and re-sign.
    style = {
      wallpapers = [ limineWallpaper ];
      wallpaperStyle = "stretched";

      interface = {
        resolution = "1920x1080";
        branding = "";
        helpHidden = true;
      };

      graphicalTerminal = {
        # The menu uses reverse video for the selected entry, so normal text is
        # white on the translucent black panel and the selection becomes a
        # white bar with black text. The palette is grayscale to match.
        palette = "000000;ffffff;ffffff;ffffff;ffffff;ffffff;ffffff;ffffff";
        brightPalette = "808080;ffffff;ffffff;ffffff;ffffff;ffffff;ffffff;ffffff";
        foreground = "ffffff";
        brightForeground = "ffffff";
        background = "cc000000";
        brightBackground = "cc000000";
        margin = 80;
        marginGradient = 8;
        font = {
          scale = "1x1";
          spacing = 1;
        };
      };
    };

    extraConfig = ''
      remember_last_entry: yes
      firmware_logo: yes
      terse: yes
    '';

    # Windows is on the Samsung ESP. Chainload it directly by GPT partition
    # GUID; firmware verifies the Microsoft signature, so no EDK2 shell (which
    # is unsigned and would stop working under Secure Boot) is needed. The
    # 8.3 form BOOTMGFW.EFI is matched case-insensitively; the long filename
    # would have to match its on-disk case exactly.
    extraEntries = ''
      /Windows
        protocol: efi
        path: guid(4427216c-77f0-4027-884d-1e394b40e929):/EFI/Microsoft/Boot/BOOTMGFW.EFI
    '';
  };

  # Limine remembers the last booted entry (Windows stays selected after a
  # Windows boot). A NixOS rebuild must still default to the new generation, so
  # activation points the remembered entry at it.
  system.activationScripts.limineLastBooted.text = ''
    if [ -d /sys/firmware/efi/efivars ]; then
      gen="$(${pkgs.coreutils}/bin/readlink /nix/var/nix/profiles/system)"
      gen="''${gen#system-}"
      gen="''${gen%-link}"
      case "$gen" in
        *[!0-9]* | "") ;;
        *)
          CHATTR=${pkgs.e2fsprogs}/bin/chattr \
            ${pkgs.python3}/bin/python3 ${limineLastBooted} \
            ${config.system.nixos.distroName} "$gen" || true
          ;;
      esac
    fi
  '';

  # TPM2 auto-unlock for the LUKS root. The TPM2 keyslot is enrolled by hand
  # after Secure Boot is active, bound to PCR 7 (the Secure Boot policy). The
  # original passphrase keyslot stays as recovery; a firmware/key change only
  # means falling back to the passphrase until re-enrolled.
  security.tpm2.enable = true;
  boot.initrd.systemd.tpm2.enable = true;
  boot.initrd.luks.devices."nixos".crypttabExtraOpts = [ "tpm2-device=auto" ];

  # Graphical boot: Plymouth owns the screen from the kernel handoff until
  # the graphical session starts, so the journal does not flash on a normal
  # boot.
  boot.plymouth = {
    enable = true;
    theme = "breeze";
  };
  boot.consoleLogLevel = 3;
  boot.kernelParams = [ "quiet" ];

  # Generation retention: five entries on the 1 GiB ESP (each generation can
  # add a ~75 MiB kernel/initrd), two weeks in the store for
  # `nixos-rebuild --rollback`.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Quickshell is the login screen, and there is no display manager: getty
  # autologins luka on tty1 only, the user's login shell execs Hyprland, and
  # the Quickshell lock daemon covers the session immediately
  # (my.desktops.lockOnStart). Logging out exits Hyprland, getty respawns and
  # the lock screen comes back. Other VTs keep a normal login prompt, so the
  # lock cannot be bypassed with Ctrl+Alt+F2.
  services.greetd.enable = lib.mkForce false;
  systemd.services."getty@".serviceConfig.ExecStart = lib.mkForce [
    ""
    (pkgs.writers.writeDash "getty" ''
      base="--noclear --keep-baud $TTY 115200,38400,9600 linux"
      if [ "$TTY" = tty1 ]; then
        exec ${lib.getExe' pkgs.util-linux "agetty"} $base --autologin luka
      fi
      exec ${lib.getExe' pkgs.util-linux "agetty"} $base
    '')
  ];

  # Secure Boot / boot-entry day-2 tools (sbctl is also used by the Limine
  # installer, but is not on PATH by default).
  environment.systemPackages = with pkgs; [
    sbctl
    efibootmgr
  ];

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
        ../../users/features/spicetify.nix
      ];

      # LiquoRice (Quickshell) is the desktop; flip to "lithe" to fall back to
      # the stable LitheDE while bringing a change up.
      my.desktops.environment = "liquorice";
      # tty1 autologins into Hyprland; the Quickshell lock screen is the login.
      my.desktops.autologin = true;
      my.desktops.lockOnStart = true;

      programs.msi = {
        enable = true;
        systemd.enable = true;
      };

      my.gdrive.enable = true;
      my.openrgb.enable = true;
      my.spicetify.enable = true;

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

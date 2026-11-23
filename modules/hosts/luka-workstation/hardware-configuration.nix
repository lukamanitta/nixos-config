{ lib, modulesPath, ... }:

# PLACEHOLDER — replace this file with the output of
# `nixos-generate-config --root /mnt` during the install (see docs/INSTALL.md).
# The values below describe the intended layout:
#
#   LUKS2 container -> btrfs with @, @home, @nix
#   1 GiB FAT32 ESP for systemd-boot (--label NIXBOOT)
#   existing 4 GiB swap partition (--label swap)
#
# It exists so `nixosConfigurations.luka-workstation` evaluates before the
# machine is installed; do not install from this file unchanged.
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  fileSystems."/" = {
    device = "/dev/mapper/nixos";
    fsType = "btrfs";
    options = [
      "subvol=@"
      "compress=zstd"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/mapper/nixos";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/mapper/nixos";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXBOOT";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-label/swap";
    }
  ];

  boot.initrd.luks.devices."nixos" = {
    device = "/dev/disk/by-partuuid/REPLACE-WITH-NIXOS-PARTUUID";
    allowDiscards = true;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

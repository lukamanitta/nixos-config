# Installing / rebuilding a host

How to take a machine from a blank disk (or a freshly-created VM) to running
this flake. Written to be repeated: the test VM now, the dev machine later.

See [ROADMAP.md](./ROADMAP.md) for where this fits in the wider plan.

## Mental model

- The flake builds a complete, bootable system. Installing = running
  `nixos-install --flake <flake>#<host>` from a NixOS ISO.
- Every machine needs its **own host entry**: its own
  `hardware-configuration.nix` (disks, filesystems, kernel modules) plus a
  `default.nix` that composes shared modules.
- Shared, hardware-agnostic settings live in `modules/hosts/core.nix` and the
  feature modules. A host should only contain what is unique to that machine.
- Never copy one machine's `hardware-configuration.nix` to another.

## 0. Before you start

- NixOS ISO (minimal is enough for the manual flow; the GNOME ISO gives you a
  GUI and NetworkManager).
- The flake pushed somewhere reachable (GitHub is easiest), or a copy you can
  put on the target.
- The target's disk name (`/dev/vda` in the VM, `/dev/nvme0n1` etc. on metal).
  Verify with `lsblk` from the ISO — do not guess.
- For a VM, **allocate the full disk size up front** (this is what bit us last
  time; resizing the virtual disk later does not grow the guest filesystem).

## 1. Boot the installer

- VM: attach the ISO in GNOME Boxes and boot it.
- Metal: boot from USB.

Get on the network (`sudo systemctl start wpa_supplicant` / `nmcli` on the
minimal ISO of old; the graphical ISO auto-connects). Confirm with
`ping nixos.org`.

## 2. Partition and mount

This mirrors the current test VM: GPT, an EFI partition, swap, and one btrfs
partition whose top level is `/` with `nix` and `home` as subvolumes.

Adjust sizes/device. **This wipes the disk.**

```bash
DISK=/dev/vda   # change me

parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart ESP fat32 1MiB 512MiB
parted "$DISK" -- set 1 esp on
parted "$DISK" -- mkpart swap linux-swap 512MiB 8GiB
parted "$DISK" -- mkpart primary 8GiB 100%

mkfs.fat -F 32 -n boot "${DISK}1"
mkswap -L swap "${DISK}2"
mkfs.btrfs -L nixos "${DISK}3"

# Create the subvolumes at the btrfs top level.
mount "${DISK}3" /mnt
btrfs subvolume create /mnt/nix
btrfs subvolume create /mnt/home
umount /mnt

# Mount the final layout: top level as /, subvolumes over nix and home.
mount "${DISK}3" /mnt
mkdir -p /mnt/nix /mnt/home /mnt/boot
mount -o subvol=nix  "${DISK}3" /mnt/nix
mount -o subvol=home "${DISK}3" /mnt/home
mount "${DISK}1" /mnt/boot
swapon "${DISK}2"
```

## 3. Generate the hardware config

```bash
nixos-generate-config --root /mnt
```

This writes `/mnt/etc/nixos/hardware-configuration.nix` (and a starter
`configuration.nix` you can ignore). The hardware config is the only file you
need from here.

## 4. Get the flake onto the target

```bash
mkdir -p /mnt/home/luka
git clone <your-repo-url> /mnt/home/luka/nixos-config
```

## 5. Create or complete the host entry

In `modules/hosts/<host>/`:

- `hardware-configuration.nix` — copy in the file from step 3.
- `default.nix` — see the template below.

Then add the host to `flake.nix`:

```nix
nixosConfigurations.<host> = nixpkgs.lib.nixosSystem {
  specialArgs = { inherit inputs; };
  modules = [
    ./modules/hosts/<host>
    home-manager.nixosModules.home-manager
  ];
};
```

> **Gotcha:** a flake in a git repo only sees *tracked* files. `git add` (or
> commit) the new host directory, or Nix will ignore it and fail on the missing
> import.

## 6. Install

```bash
nixos-install --flake /mnt/home/luka/nixos-config#<host>
```

If flakes are not enabled in the installer:

```bash
nixos-install --flake /mnt/home/luka/nixos-config#<host> \
  --option experimental-features "nix-command flakes"
```

You will be prompted to set the **root** password. Reboot when it finishes.

## 7. First boot

- Log in as `root` at the console with the password from step 6.
- The user account has no password yet, so set one:
  ```bash
  passwd luka
  ```
  (Or declare `users.users.luka.initialHashedPassword` in the config.)
- Log in as `luka`; Home Manager activates via the NixOS module. Verify with
  `home-manager generations`.

## 8. Rebuilding the test VM (shortcut)

If you are only re-creating `luka-nixos-test` on the same virtual hardware,
skip the new-host work: after step 3, overwrite
`modules/hosts/luka-nixos-test/hardware-configuration.nix` with the generated
file (they will be nearly identical), then `nixos-install` that host. Keep the
old copy until the new install boots.

## 9. Dev machine (full replacement, no dual-boot) notes

Switching the machine to NixOS rather than dual-booting, so it is a clean
install — but destructive:

- Back up everything you care about first, and confirm the backup *restores*,
  not just that it ran.
- NixOS will own the bootloader; `core.nix` already enables `systemd-boot` +
  `efi.canTouchEfiVariables`, which is what you want on UEFI hardware.
- Confirm the firmware is UEFI (not legacy BIOS) and the disk uses GPT.
- Do a full end-to-end dry run on the test VM first; migrate only once the
  parity checklist in the ROADMAP passes.

## Appendix: `modules/hosts/<host>/default.nix`

```nix
{ inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../core.nix
    ../../users/luka/system.nix
  ];

  networking.hostName = "<hostname>";

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;

    users.luka = {
      imports = [ ../../users/luka/home.nix ];
    };
  };

  system.stateVersion = "26.05";
}
```

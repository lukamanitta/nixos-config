# Removing Arch — NixOS takes the whole WD drive

Endgame for [WORKSTATION.md](./WORKSTATION.md). Windows on `nvme0n1` is never
part of this; only the WD disk (`nvme1n1`) is repartitioned.

Read [WORKSTATION-TROUBLESHOOTING.md](./WORKSTATION-TROUBLESHOOTING.md) first.
The device-name and `parted -s` traps apply here too, and this procedure
destroys data by design.

## Gate: do not start until all of these are true

- [ ] A full workday was done on NixOS with no Arch fallback needed.
- [ ] The parity checklist in [ROADMAP.md](./ROADMAP.md) is satisfied, or the
      gaps are accepted in writing.
- [ ] A restic backup newer than the last meaningful change exists and a test
      restore of one file succeeded.
- [ ] The rescue list below is copied **off the WD disk**, not just to the
      NixOS home (the home is wiped in path A).
- [ ] You know the LUKS passphrase and have decided whether to add a recovery
      keyslot before flattening.

## Installer media

- `nixos-minimal-26.05.11045.774debe7a0d1-x86_64-linux.iso`, SHA-256
  `81fdbaa462f15a2eb36b4c6a9e3b8d3430b847d9bf63dda36cb8456632a4403b`, already on
  the Ventoy stick (`sda`, SanDisk 3.2Gen1). Boot the **minimal 26.05 UEFI**
  entry; the 25.11 graphical ISO on the same stick is not the one this was
  tested with.
- Keep **Secure Boot off** until lanzaboote is installed: Ventoy and the NixOS
  ISO are unsigned.

## Rescue list — things that only exist on Arch

Arch's `@home` (p3) and its snapshots disappear. Recover these first, to an
external drive or a password manager:

| Item | Path on Arch | Why |
|---|---|---|
| restic password | `~/.config/restic/luka-workstation.pass` | Without it the Google Drive repo is unreadable. **Highest priority.** |
| rclone OAuth | `~/.config/rclone/rclone.conf` | Personal client ID; re-auth is possible but annoying. |
| SSH private keys | subvolume `@ssh` (not `@home`) | Already copied to NixOS `~/.ssh`; verify perms `0700`/`0600`. |
| SSH/GPG agent keys | `~/.gnupg` if present | Not covered by the NixOS copy. |
| `~/code` trees | e.g. `~/code/msi` beyond `msi-nix` | `msi-nix` is on NixOS; the rest may not be. |
| `msi-nix` remote + rev | `git -C ~/code/msi-nix remote -v; git rev-parse HEAD` | The flake pins it by absolute path; a reinstall has to re-clone it at rev `21732288b9700ed2dd9c283ad0c0defc6893db17`. |
| dotfiles repo | `~/dotfiles` | Different machine per `AGENTS.md`, but check for anything unique. |
| Browser profiles | `~/.config/{zen,chromium}` | Mostly excluded from restic; rely on sync, or copy by hand. |
| Anything from older file versions | `@snapshots/<n>/snapshot` | Snapper snapshots are the only history once the disk is gone. |
| Arch package list | `pacman -Qqe` | Reference for parity gaps. |

## Why "just grow p5" does not work

NixOS lives in p5, which is **last** on the disk. The space that Arch occupies
(p1–p3) is *before* p5, and p5 begins with the LUKS2 header. A LUKS container
cannot be moved or extended backwards without re-encrypting its contents, so
deleting Arch does not give NixOS a bigger root via `resizepart`. That leaves
two honest options.

## Path A — clean re-layout and reinstall (recommended)

This is what D45/D49 assumed: NixOS ends up with a 1 GiB ESP and one LUKS2
partition filling the disk, with no legacy layout to work around.

1. **Snapshot the current state** for reference:

   ```sh
   nixos-rebuild list-generations
   sudo sgdisk -p "$(readlink -f /dev/disk/by-id/nvme-WDC_PC_SN720_SDAPNTW-512G-1006_190350802260)"
   ```

2. **Copy `~/` (minus caches) to an external drive**, and separately back up
   with restic. The external copy is the fast path for restoring; restic is the
   safety net. Verify at least one restored file matches.

3. **Boot the NixOS minimal ISO** (Ventoy, UEFI) and identify the disk:

   ```sh
   ARCH_DISK=/dev/disk/by-id/nvme-WDC_PC_SN720_SDAPNTW-512G-1006_190350802260
   lsblk -dno MODEL,SERIAL,SIZE "$ARCH_DISK"     # must be WDC PC SN720 / 476.9G
   ```

4. **Repartition.** This destroys Arch. Confirm the model string above first.
   This layout mirrors today's numbering — p1 ESP, p2 swap, p3 LUKS — so the
   host modules need no edits beyond regenerating
   `hardware-configuration.nix`.

   ```sh
   sgdisk --zap-all "$ARCH_DISK"
   parted -s "$ARCH_DISK" mklabel gpt
   parted -s "$ARCH_DISK" unit MiB mkpart NIXBOOT fat32 1MiB 1025MiB
   parted -s "$ARCH_DISK" set 1 esp on
   parted -s "$ARCH_DISK" unit MiB mkpart swap linux-swap 1025MiB 5121MiB
   parted -s "$ARCH_DISK" unit MiB mkpart NIXROOT 5121MiB 100%
   partprobe "$ARCH_DISK"; udevadm settle
   sgdisk -p "$ARCH_DISK"
   ```

   If you would rather drop disk swap and use zram, skip the `swap` partition,
   start `NIXROOT` at `1025MiB`, then set `zramSwap.enable = true;` and delete
   the `swapDevices` entry that `nixos-generate-config` writes. Doing neither
   leaves the system with no swap at all.

5. **Format and lay out btrfs:**

   ```sh
   mkfs.fat -F 32 -n NIXBOOT "${ARCH_DISK}-part1"
   mkswap -L swap "${ARCH_DISK}-part2"
   cryptsetup luksFormat --type luks2 --label NIXROOT "${ARCH_DISK}-part3"
   cryptsetup open "${ARCH_DISK}-part3" nixos
   mkfs.btrfs -L nixos /dev/mapper/nixos

   mount /dev/mapper/nixos /mnt
   btrfs subvolume create /mnt/@ /mnt/@home /mnt/@nix
   umount /mnt

   mount -o subvol=@,compress=zstd /dev/mapper/nixos /mnt
   mkdir -p /mnt/home /mnt/nix /mnt/boot
   mount -o subvol=@home,compress=zstd /dev/mapper/nixos /mnt/home
   mount -o subvol=@nix,compress=zstd,noatime /dev/mapper/nixos /mnt/nix
   mount "${ARCH_DISK}-part1" /mnt/boot
   swapon "${ARCH_DISK}-part2"
   ```

   zram variant: there is no swap partition, so `p2` is the LUKS partition —
   drop `mkswap`/`swapon` and use `-part2` in the `cryptsetup` lines.

6. **Know what changes.** The LUKS UUID, btrfs UUID, ESP FAT UUID and swap UUID
   are all new; nothing outside the regenerated
   `hardware-configuration.nix` references the old ones. The passphrase can stay
   the same (US layout at the initrd prompt).

7. **Get the repo onto the ISO.** The old home is gone, so clone instead of
   copying:

   ```sh
   mkdir -p /home/luka /home/luka/code
   git clone https://github.com/lukamanitta/nixos-config /home/luka/nixos-config
   git clone <msi-nix remote> /home/luka/code/msi-nix
   nixos-generate-config --root /mnt
   cp /mnt/etc/nixos/hardware-configuration.nix \
      /home/luka/nixos-config/modules/hosts/luka-workstation/hardware-configuration.nix
   nixos-install --flake /home/luka/nixos-config#luka-workstation \
     --option extra-substituters https://cache.forall.systems \
     --option extra-trusted-public-keys 'cache.forall.systems:5PmD7QO4MSF8YgyRZtkSGXRDo96H3bybIf2SsQh8ScI='
   ```

   `msi-nix` must be at the absolute path from `flake.nix`
   (`/home/luka/code/msi-nix`) in the installer environment **and** at the
   pinned rev `21732288b9700ed2dd9c283ad0c0defc6893db17` (record the remote URL
   before wiping — see the rescue list).

8. **Restore the home** after first boot: mount the external drive and copy
   `~/`, or restore with restic (needs `rclone.conf` and the restic password
   from the rescue list). Keep the new `~/nixos-config` from the clone, then
   reconcile with the backup.

9. **Firmware cleanup:** the old rEFInd entries now point at a deleted ESP.

   ```sh
   sudo efibootmgr -v
   sudo efibootmgr -b 0001 -B      # one per stale rEFInd entry; numbers differ
   sudo efibootmgr -o <order>      # Linux Boot Manager first
   ```

10. **Verify:** boot NixOS, `findmnt -R /`, `df -h /boot`, `lsblk`, Windows from
    the systemd-boot menu, and `sudo nixos-rebuild switch`.

## Path B — keep the install, add the freed space as a second device

Only if the reinstall is unacceptable. Preconditions: backup verified, and
space freed in front of p5 is acceptable to you.

1. Deal with swap first: `sudo swapoff -a` (p2 is the swap partition and is
   about to disappear). Add `zramSwap.enable = true;` and drop `swapDevices`, or
   create a new swap partition in the freed space and keep the entry.
2. In the running NixOS, delete Arch's partitions and create one replacement in
   the freed space. Nothing of Arch is mounted, so this is safe while NixOS
   runs:

   ```sh
   sudo sgdisk -d 1 -d 2 -d 3 "$ARCH_DISK"        # ESP, swap, Arch root
   sudo parted -s "$ARCH_DISK" unit MiB mkpart NIXROOT2 1MiB <end>MiB
   sudo partprobe "$ARCH_DISK"
   ```

   Leave the new partition ending where p4 begins. Do not touch p4/p5.
3. Encrypt it and add it to the live filesystem:

   ```sh
   sudo cryptsetup luksFormat --type luks2 --label NIXROOT2 "${ARCH_DISK}-part1"
   sudo cryptsetup open "${ARCH_DISK}-part1" nixos2
   sudo btrfs device add /dev/mapper/nixos2 /
   sudo btrfs balance start -dusage=50 /
   ```

4. Add `boot.initrd.luks.devices."nixos2"` (same `device`/by-uuid form as
   `"nixos"`), rebuild, reboot — and expect a second passphrase prompt unless
   you add a keyfile.

Costs, which is why A is recommended: the root filesystem spans two partitions
on one disk, both must unlock at boot, a single partition failure degrades the
whole filesystem, and the ESP stays stranded at p4 with gaps below it. Nothing
gained over a reinstall except time.

## After Arch is gone

- **Secure Boot** (deferred by D41): lanzaboote with custom keys. Do it once the
  disk layout is final, since it changes how kernels are signed and booted.
- Re-check `boot.loader.systemd-boot.configurationLimit` against the new ESP
  size, and `df -h /boot` after a few generations.
- Consider adding `allowDiscards = true` to the LUKS device now that there is
  no dual-boot reason to avoid extra writes.
- Decide whether snapshots are wanted. NixOS generations cover
  `/nix`-adjacent rollbacks; `/home` rollback would need snapper or
  `btrfs subvolume snapshot`, which is also why `@ssh` might get its own
  subvolume then (see D46).
- Update [ROADMAP.md](./ROADMAP.md) checkboxes and this document's status.

# Handoff — luka-workstation

Generated **2026-11-24, after the install**. Supersedes the pre-install handoff
(which described an MBR disk, a 120 GiB carve-out, and a Windows handle of
`FS1`; all three changed).

Repo: `https://github.com/lukamanitta/nixos-config`. The target machine is the
desktop, not the MacBook. Per `AGENTS.md`, work from the repo on the Mac and
only trust live state on the machine itself.

## Where things stand

- **NixOS is installed and boots.** LUKS2 unlock, btrfs subvolumes, swap, and
  systemd-boot on its own 1 GiB ESP all work.
- **Arch is intact** on the WD disk (p1 ESP + p2 swap + p3 root) and is
  reachable via rEFInd in the firmware menu — boot it once to confirm, since the
  GPT conversion changed partition GUIDs. It is the fallback until a full
  workday passes.
- **Windows is untouched** on the Samsung NVMe.
- The WD disk was **converted from MBR to GPT** during the install; it is fully
  allocated and has no free space.

Details: [WORKSTATION.md](./WORKSTATION.md) (disk map, boot map, day-2
commands), [WORKSTATION-TROUBLESHOOTING.md](./WORKSTATION-TROUBLESHOOTING.md)
(every trap hit so far), [WORKSTATION-ARCH-REMOVAL.md](./WORKSTATION-ARCH-REMOVAL.md)
(the endgame).

## Facts a resumed session needs first

- WD disk: `/dev/disk/by-id/nvme-WDC_PC_SN720_SDAPNTW-512G-1006_190350802260`
  (serial `190350802260`). Device names swap; never use `/dev/nvmeXn1`.
- NixOS: p4 1 GiB vfat `NIXBOOT` (fs UUID `261B-9CAD`) + p5 LUKS2
  `NIXROOT` (UUID `b6191a65-7b50-4a79-8865-89dc8d7b7332`, mapper `nixos`,
  btrfs label `nixos`, subvols `@`/`@home`/`@nix`).
- Swap is Arch's p2, UUID `2e4e9d1b-e843-42be-8340-32eff0b609e5`, unencrypted.
- Firmware entry is labelled **`Linux Boot Manager`**, not NixOS. rEFInd shows
  up only in the firmware menu (F12), never in systemd-boot.
- Windows chainloads through `efiDeviceHandle = "FS0"`; rediscover with
  `map -r` in the EDK2 shell if it breaks.
- LUKS passphrase is typed on a **US layout**; there is no recovery keyslot.
- `it87` needs **both** `acpi_enforce_resources=lax` and the out-of-tree module
  `config.boot.kernelPackages.it87` for the IT8696 to be recognised.

## Known repo gap

`boot.extraModulePackages = [ config.boot.kernelPackages.it87 ];` is required
for CoolerControl and was applied on the machine, but as of this handoff it is
**not committed**. Check:

```sh
git grep extraModulePackages modules/hosts/luka-workstation/
```

If it only finds the generated `hardware-configuration.nix` (which lists an
empty list), add it to `hardware.nix` as shown in the troubleshooting doc
before trusting a fresh checkout or a reinstall.

## Not verified yet

- Windows actually booting from the systemd-boot menu.
- Affinity `affinity-v3`, OBS capture, OpenRGB (`true-white`, ENE DRAM
  controllers + IT5711), CoolerControl fan curves applying from the seed.
- `rclone-gdrive` at `~/mnt/gdrive`, `gdrive-pin`, `tailscale up`.
- DaVinci Resolve (opt-in; RDNA4 + ROCm 7.2.x remains unproven).

## Next actions in order

1. Commit the `it87` module package line (above) and push.
2. Work through the "Not verified yet" list; record failures in the
   troubleshooting doc rather than fixing them silently.
3. Do a full NixOS workday. Keep Arch bootable until it passes.
4. Copy the restic password and `rclone.conf` **off the WD disk** — they are the
   only things the removal procedure cannot recreate.
5. Then follow [WORKSTATION-ARCH-REMOVAL.md](./WORKSTATION-ARCH-REMOVAL.md)
   path A (re-layout + reinstall + restore). Secure Boot comes after that.

## Repo state at handoff

- `hardware-configuration.nix` for this host is now the generated file, committed.
- `gh.nix` disables `xdg.configFile."gh/config.yml"` so `gh` can write it.
- `hardware.nix` has `acpi_enforce_resources=lax`.
- `default.nix` has `efiDeviceHandle = "FS0"`.
- Docs: this file, `WORKSTATION.md`, `WORKSTATION-TROUBLESHOOTING.md`,
  `WORKSTATION-ARCH-REMOVAL.md`, `DECISIONS.md` D45–D49, `ROADMAP.md`.

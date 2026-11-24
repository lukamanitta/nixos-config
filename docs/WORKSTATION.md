# luka-workstation (Arch → NixOS)

The personal desktop: Ryzen 7 9800X3D, Radeon RX 9070 XT + Radeon 610M iGPU,
Gigabyte B850M GAMING X WIFI6E, 30 GiB RAM, RTL8852CE Wi-Fi/Bluetooth,
RTL8125 Ethernet, IT8696 fan controller.

**Status: installed 2026-11-24, running a dual-boot trial.** NixOS owns a new
1 GiB ESP + a LUKS2/btrfs partition on the WD NVMe; Arch is still intact
alongside it as the fallback; Windows is untouched on the Samsung.

Companion docs:

- [WORKSTATION-TROUBLESHOOTING.md](./WORKSTATION-TROUBLESHOOTING.md) — every
  failure this install produced, with causes and fixes. Read this before
  changing the disk layout, boot entries, `it87`, or `gh`.
- [WORKSTATION-ARCH-REMOVAL.md](./WORKSTATION-ARCH-REMOVAL.md) — how to end up
  with NixOS only on the WD drive, including what must be rescued from Arch
  first.
- [HANDOFF.md](./HANDOFF.md) — the current state in one page.

## Disks (verified 2026-11-24, after the install)

Device names have already swapped once on this machine, and the kernel's
major:minor numbers do not follow the names either (`blkid` reported the WD
disk as `259:0` while it was `/dev/nvme1n1`). **Always address a disk through
`/dev/disk/by-id/`.**

| Role | Device | Size | Model | Serial |
|---|---|---|---|---|
| Arch + NixOS | `nvme1n1` | 476.94 GiB, 1000215216 sectors | WDC PC SN720 SDAPNTW-512G-1006 | `190350802260` |
| Windows | `nvme0n1` | 3.6 TB | Samsung SSD 990 EVO Plus 4TB | `S7U9NJ0Y515764R` |
| Ventoy USB | `sda` | 114.6 GB | SanDisk 3.2Gen1 | `03005420082825095350` |

Stable path for the WD disk:

```sh
ARCH_DISK=/dev/disk/by-id/nvme-WDC_PC_SN720_SDAPNTW-512G-1006_190350802260
```

### WD NVMe layout — **GPT** since 2026-11-24

The disk was MBR (`msdos`, disk id `0x66e96915`) when Arch was installed. It was
converted to GPT during the NixOS install because MBR allows only four primary
partitions and the plan needs five. See
[WORKSTATION-ARCH-REMOVAL.md](./WORKSTATION-ARCH-REMOVAL.md) and
[DECISIONS.md](./DECISIONS.md) D45 for why, and the troubleshooting doc for the
`sgdisk` failure that conversion causes if the last partition still reaches the
end of the disk.

| # | Sectors | Size | FS / name | Notes |
|---|---|---|---|---|
| p1 | 2048–1050623 | 512 MiB | vfat, Arch ESP, fs UUID `9369-6B68` | rEFInd (`EFI/refind/refind_x64.efi`), a stale `EFI/systemd/systemd-bootx64.efi`, UKIs in `EFI/Linux/`, `EFI/BOOT/BOOTX64.EFI`. ~302 MiB used. **Arch's fallback — not NixOS's.** |
| p2 | 1050624–9439231 | 4 GiB | swap, UUID `2e4e9d1b-e843-42be-8340-32eff0b609e5` | Arch's swap, **reused by NixOS** (`swapDevices`). Unencrypted. |
| p3 | 9439232–748562431 | 352.44 GiB | btrfs, fs UUID `7331adf4-2345-4553-8570-b2ce1fa35729` | Arch root. Subvolumes `@`, `@var`, `@opt`, `@home`, `@ssh`, `@snapshots`, `@home-snapshots` (+ nested `@var/lib/{machines,portables}`, `@snapshots/<n>/snapshot`). **The only copy of Arch.** |
| p4 | 748562432–750659583 | 1 GiB | vfat label `NIXBOOT`, PARTUUID `ec04e73a-e98c-4087-b20b-0d4276580eb8`, fs UUID `261B-9CAD` | NixOS ESP, systemd-boot. |
| p5 | 750659584–1000215215 | ~119 GiB | LUKS2 label `NIXROOT`, UUID `b6191a65-7b50-4a79-8865-89dc8d7b7332` → mapper `nixos` → btrfs label `nixos` | NixOS root. Subvolumes `@`, `@home`, `@nix`. |

The disk is fully allocated: no free space remains after p5. Growing NixOS
therefore means deleting Arch (see the removal doc) — p5's LUKS header sits at
its front, so it cannot grow backwards into freed space.

### Windows NVMe (never modify)

`nvme0n1`, GPT: p1 100 MiB ESP (partition GUID
`4427216c-77f0-4027-884d-1e394b40e929`), p2 16 MiB MSR, p3 3.6 TB NTFS, p4
819 MiB NTFS recovery. Plain NTFS, no BitLocker, Fast Startup off. Firmware
entry `Windows Boot Manager` (`Boot0000`).

## Boot

- NixOS boots from p4 via systemd-boot. Its NVRAM entry is labelled
  **`Linux Boot Manager`**, not "NixOS" — that is `bootctl`'s own label.
- Arch boots via rEFInd on p1. rEFInd is a separate EFI application, so it
  appears in the **firmware boot menu** (F12), never in systemd-boot's menu.
  There are two redundant `rEFInd` NVRAM entries: `Boot0001`, which predates the
  MBR→GPT conversion, and `Boot0002`, recreated with `efibootmgr` immediately
  afterwards. Both load the same binary; keep one and delete the other when
  tidying firmware entries.
- Windows is chainloaded by systemd-boot through the EDK2 shell handle in
  `boot.loader.systemd-boot.windows."Windows".efiDeviceHandle`, currently
  **`FS0`** (found with `map -r` in the shell). systemd-boot cannot read another
  ESP, which is why this indirection exists.
- `boot.loader.systemd-boot.edk2-uefi-shell.enable = true` provides the shell
  entry used for `map -r`, for reaching Windows' ESP, and as the escape hatch
  into Arch: from the shell, `FSx:\EFI\refind\refind_x64.efi`.
- `boot.loader.systemd-boot.configurationLimit = 10` on a 1 GiB ESP. Watch
  `df -h /boot`; each generation costs roughly 50–60 MiB.

## Filesystem/encryption decisions as installed

- LUKS2, passphrase, **US keyboard layout at the initrd prompt**, no recovery
  keyslot yet. Adding a keyslot later is cheap; losing the passphrase is not.
- btrfs `@`, `@home`, `@nix` with `compress=zstd`; `/nix` also `noatime`.
- `hardware-configuration.nix` was generated by `nixos-generate-config` on the
  installed system. It names the LUKS device `nixos` (from the mapper name) and
  references it as `/dev/disk/by-uuid/b6191a65-…`. It does **not** set
  `allowDiscards`.
- Swap is Arch's plain p2. No hibernation.
- `time.hardwareClockInLocalTime = true` for the Windows dual boot.

## Repo map (host-specific)

- `modules/hosts/luka-workstation/default.nix` — hostname, MSI, Tailscale,
  OpenRGB (root service disabled), CoolerControl, Bluetooth, boot loaders,
  Windows handle, RTC-in-local-time, Affinity substituter, Home Manager wiring.
- `modules/hosts/luka-workstation/hardware.nix` — CPU/GPU/i2c/microcode/
  redistributable firmware, `it87`, and `acpi_enforce_resources=lax`.
- `modules/hosts/luka-workstation/hardware-configuration.nix` — **generated**;
  commit changes to it deliberately, never hand-invent device paths.
- `modules/hosts/luka-workstation/files/{openrgb,coolercontrol}/` — seeds, not
  live state.
- `modules/users/features/gh.nix` — `programs.gh` with `gitCredentialHelper`,
  plus the `xdg.configFile."gh/config.yml".enable = false` override.
- `modules/users/features/creative.nix` — Affinity, DaVinci (opt-in), Discord,
  Slack, Spotify, VLC, OBS.
- `modules/users/features/gdrive.nix`, `.../openrgb.nix` — per-user features.

## Day-2 commands

```sh
sudo nixos-rebuild switch --flake ~/nixos-config#luka-workstation   # apply
sudo nixos-rebuild boot  --flake ~/nixos-config#luka-workstation    # kernel params
sudo nix-collect-garbage -d                                          # after pruning
```

Kernel-parameter and initrd changes need `switch` **and** a reboot; `switch`
alone leaves the running kernel as it was.

State that is not in the store and must be recreated by hand after a reinstall:
`tailscale up`, `~/.config/rclone/rclone.conf`, `gh auth login`, the
CoolerControl admin password, and any `~/.ssh` keys (they live in `@home` on
NixOS — the Arch `@ssh` subvolume was deliberately **not** carried over as a
separate subvolume).

## Working on the flake from the Mac

`flake.nix` pins `msi-nix` to the absolute input
`git+file:///home/luka/code/msi-nix`, which does not exist on macOS. Any flake
evaluation there fails until it is overridden:

```sh
git clone <msi-nix remote> ~/code/msi-nix
nix flake check --override-input msi-nix path:~/code/msi-nix
```

Do not "fix" this by changing the input to a relative path without deciding
where `msi-nix` is meant to live for every host.

## Post-install state (2026-11-24)

Done and verified:

- Install, first boot, LUKS unlock, btrfs subvolumes, swap.
- systemd-boot on its own ESP; `Linux Boot Manager` NVRAM entry.
- Windows handle `FS0` found through the EDK2 shell and committed.
- `it87` loads against the IT8696 via the out-of-tree module (committed in
  `672069b`); CoolerControl reads the Super I/O and **fan curves work**.
- `gh` can write its own `config.yml`; authentication works.
- Tailscale is up.
- Affinity launches.

Not yet verified — do these before declaring the trial passed:

- [ ] Arch still boots via rEFInd from the firmware menu (the GPT conversion
      changed partition GUIDs; prove the fallback before trusting it).
- [ ] Windows entry actually boots Windows from the systemd-boot menu.
- [ ] Affinity opens a document and the plugin loader works (it launches).
- [ ] OBS: PipeWire screen capture + audio.
- [ ] OpenRGB: `true-white` loads; two ENE DRAM controllers + IT5711 visible
      (RAM detection is known-flaky and deliberately not chased).
- [ ] CoolerControl seed review: `All Case Fans` (fan1/fan2) is what you want,
      but the seed is 5.0.1-shaped against a 5.1.2 daemon, so glance at
      `/var/lib/coolercontrol/config.toml`.
- [ ] `rclone-gdrive` mount at `~/mnt/gdrive`, and `gdrive-pin`.
- [ ] Wi-Fi (RTL8852CE) and Bluetooth pairing — both untested on NixOS.
- [ ] Monitor layout: `DP-2` at `0x0` and `HDMI-A-2` at `0x1080`, both preferred.
- [ ] DaVinci Resolve: still opt-in (`my.creative.davinciResolve = true`) and
      still unproven on RDNA4 + ROCm 7.2.x.
- [ ] A full workday on NixOS, then plan Arch removal.

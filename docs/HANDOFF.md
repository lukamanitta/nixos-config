# Handoff — NixOS workstation install

Generated **2026-11-24** while the Arch workstation is still running. The
OpenCode session exported to the MacBook was partially corrupt (missing images
and attachments); **this document is the source of truth** for resuming.

Repository: `https://github.com/lukamanitta/nixos-config` (pushed).
The target is the Arch desktop being converted to NixOS, not the MacBook.

---

## Current state (read this first)

- **No destructive action has been taken.** Arch is still the running system.
- Arch has been backed up and snapshotted; the Ventoy USB is prepared.
- The next action is: reboot → Ventoy → **NixOS minimal 26.05 UEFI** →
  `sudo -i` → `lsblk` → verify disks → follow
  [WORKSTATION.md](./WORKSTATION.md) section 3.
- Do **not** run the `btrfs resize`/`parted` block until the disk identities are
  confirmed. Device names swapped between reboots once already.

### Disks (as of 2026-11-24, before reboot)

| Role | Device | Size | Model | Layout |
|---|---|---|---|---|
| Arch | `nvme1n1` | 476.9 G | WDC PC SN720 | p1 vfat `/efi`, p2 swap 4 G, p3 btrfs `/` + `/home` |
| Windows | `nvme0n1` | 3.6 T | Samsung SSD 990 EVO Plus 4 TB | p1 100 M ESP, p2 16 M, p3 NTFS, p4 819 M NTFS |
| Ventoy USB | `sda` | 114.6 G | SanDisk 3.2Gen1 | exFAT data + 32 M VTOYEFI |

Windows appears to be plain NTFS (no BitLocker), and Fast Startup is reported
off. Arch has ~187 GiB free.

### Boot / USB / ISO

- Ventoy already contains:
  `nixos-minimal-26.05.11045.774debe7a0d1-x86_64-linux.iso`
  and its SHA-256 matches the official release:
  `81fdbaa462f15a2eb36b4c6a9e3b8d3430b847d9bf63dda36cb8456632a4403b`.
- Boot the **minimal 26.05** entry, UEFI mode. Do not use the 25.11 graphical
  ISO also present on the stick.
- The session JSON was copied to the Mac and imported; it is incomplete. Ignore
  its missing images/attachments and use this document plus the repo docs.

### Backups

- restic repo: `rclone:gdrive:backups/luka-workstation`
- snapshots:
  - `12d1374a` — full, 2026-11-23, 36.5 GiB, ~135k files
  - `d313a1ef` — incremental, 2026-11-24, 44 s (57 new, 42 changed),
    same 36.5 GiB
- password: `~/.config/restic/luka-workstation.pass` on Arch (not in git).
  **The user must keep this; without it the backup cannot be restored.**
- `restic check --read-data-subset=1%` passed; a test restore of
  `nixos-config/flake.nix` matched.
- Google Drive rclone remote: `gdrive`, own OAuth client ID now configured
  (client secret/token stay in `~/.config/rclone/rclone.conf`, never in git).
- Snapper keeps `1`, `1157`, `2533`, `2535`, `3124`–`3127`, and
  `3128 Pre NixOS install`. Older snapshots were deleted.

---

## What has been built

Host entry: `modules/hosts/luka-workstation/`

- `default.nix` — hostname `luka-workstation`, MSI/NixOS module, Tailscale,
  OpenRGB, CoolerControl, Bluetooth, Windows boot entry, local RTC, Nix cache
  for Affinity.
- `hardware.nix` — Ryzen 9800X3D, RX 9070 XT + 610M, 32-bit graphics,
  ROCm/OpenCL, i2c, `it87`, AMD microcode, firmware.
- `hardware-configuration.nix` — **placeholder**; replace with the output of
  `nixos-generate-config` during install.
- `files/openrgb/profiles/{true-white,Off}.json` — copied from the Arch
  OpenRGB profile.
- `files/coolercontrol/{config.toml,overrides.toml}` — copied from the Arch
  CoolerControl 5.0.1 setup (IT8696: fan1/fan2 “All Case Fans”, fan3/fan5
  default).

Creative stack: `modules/hosts/features/creative.nix`

- Affinity v3 via `mrshmllow/affinity-nix` (overlay, unfree, binary cache).
- Native Discord, Slack, Spotify, VLC, OBS.
- DaVinci Resolve is **opt-in** (`my.creative.davinciResolve = true`) because
  the nixpkgs 20.3.2 source fetch fails before the build. RDNA4/ROCm is a known
  risk; keep Arch/Windows as fallback until proven.
- Narrow unfree predicate; no Flatpak for the must-have apps.

User features:

- `modules/users/features/gdrive.nix` — `rclone mount` with full VFS cache
  (30 GiB default, tunable under `my.gdrive`), plus `gdrive-pin`. The rclone
  OAuth config is a manual copy from Arch.
- `modules/users/features/openrgb.nix` — user OpenRGB SDK server, owns
  `true-white`, reads profiles from `~/.config/OpenRGB`; root service disabled.
  `colourme`’s `openrgb -c ...` hook still works against the server.
- `programs.msi.systemd.enable = true` on the workstation; MSI services start at
  login and apps socket-activate.

Docs/scripts:

- `docs/WORKSTATION.md` — hardware, decisions, exact install commands,
  post-install checks. **Primary runbook.**
- `docs/DECISIONS.md` — D40–D44 cover the workstation decisions.
- `docs/ROADMAP.md` — migration checklist (backup checked; install not).
- `scripts/arch-cleanup.sh` — dry-run by default; safe caches, Trash, ollama,
  paru AUR clones; keeps the DaVinci build tree unless `--davinci-build`.
- `scripts/pre-nixos-backup.sh` — restic to Google Drive.

Flake inputs added: `affinity-nix`, `coolercontrol` (nixpkgs follows the main
pin). Output: `nixosConfigurations.luka-workstation`.

### Validation (on Arch, 2026-11-24)

- `nix flake check --no-build`: passes for both hosts.
- Home Manager generation: builds.
- Full `luka-workstation` system: **builds**, closure ≈ 19.4 GiB.
- `affinity-v3`: **builds**, ≈ 6.2 GiB.
- CoolerControl 5.1.2, Slack, Discord, Spotify, OBS: build.
- DaVinci Resolve: source fetch fails (vendor server); opt-in/unverified.
- Not installed or run on real hardware yet.

---

## Decisions already settled

1. **Dual-boot first, wipe Arch after a full workday.** New 1 GiB ESP +
   systemd-boot for NixOS; Arch keeps its rEFInd ESP as fallback. Windows stays
   on the Samsung.
2. **LUKS2 passphrase + btrfs** `@`, `@home`, `@nix`; reuse the existing 4 GiB
   swap. Secure Boot deferred until Arch is gone (then lanzaboote + custom
   keys).
3. **Native apps, no Flatpak** for the must-have set. Discord is the official
   native client first; Vesktop only if Wayland screen sharing is poor.
4. **Affinity via the flake**, not the 2 GB AppImage. First build is heavy;
   `cache.forall.systems` is configured in the host.
5. **OpenRGB/CoolerControl are seeded, not locked.** OpenRGB runs as the user
   and loads `true-white`; CoolerControl’s config is copied once, then the
   daemon owns it. RAM detection is inconsistent and **deliberately not
   retried yet**.
6. **Google Drive** is a tuned rclone mount, not the old cache-less mount.
   Backups are restic to Drive.
7. **Stable 26.05**; newer packages come from the flakes.
8. Desktop default is **LitheDE** (switch to `"liquorice"` when wanted).
   Monitors: `DP-2` at `0x0`, `HDMI-A-2` at `0x1080`, both preferred.

---

## Install plan (next)

Read [WORKSTATION.md](./WORKSTATION.md) sections 2–6; this is the short version.

1. Boot the minimal ISO in UEFI mode.
2. `sudo -i`; run `lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL,PARTUUID,MOUNTPOINTS`.
   Confirm Arch = ~477 G WD, Windows = 3.6 T Samsung, USB = SanDisk. Do not
   trust the `nvmeXn1` names.
3. Shrink the Arch btrfs filesystem by 120 GiB from the ISO:
   mount `subvolid=5`, `btrfs filesystem resize -120G`, unmount.
4. Shrink `p3` with `parted` to the new end; create:
   - 1 GiB FAT32 `NIXBOOT`, ESP flag
   - the rest as `NIXROOT`
   Verify partition numbers before running the commands.
5. LUKS2 on `NIXROOT`; btrfs `@`, `@home`, `@nix`; mount them under `/mnt`;
   mount `NIXBOOT` at `/mnt/boot`; `swapon` the existing swap.
6. Mount the Arch `@home` read-only, copy:
   - `/mnt/arch/luka/nixos-config` → `/mnt/home/luka/nixos-config`
   - `/mnt/arch/luka/code/msi-nix` → `/mnt/home/luka/code/msi-nix`
   - also copy `msi-nix` to `/home/luka/code/msi-nix` **inside the ISO**;
     `flake.nix` uses the absolute input
     `git+file:///home/luka/code/msi-nix`, so evaluation fails without it.
7. `nixos-generate-config --root /mnt`; copy the generated
   `hardware-configuration.nix` over the placeholder in the repo.
8. `nixos-install --flake /mnt/home/luka/nixos-config#luka-workstation` with:
   ```sh
   --option extra-substituters https://cache.forall.systems \
   --option extra-trusted-public-keys 'cache.forall.systems:5PmD7QO4MSF8YgyRZtkSGXRDo96H3bybIf2SsQh8ScI='
   ```
   CoolerControl may build on the target; Affinity should use its cache.
9. First boot: log in as `luka` or reset via root. Set the Windows boot entry:
   open the EDK2 shell entry, run `map -c`, find the Windows ESP
   (`ls FSx:\EFI\Microsoft\Boot\bootmgfw.efi`), then replace the placeholder
   `efiDeviceHandle = "FS1"` in the host and rebuild.
10. Copy the rest of `~/code/msi` (only `msi-nix` is copied during install),
    copy `~/.config/rclone/rclone.conf`, run `tailscale up`, and test the
    creative stack.

---

## Post-install checks

- `tailscale up` (manual auth; state not in the store).
- Copy `rclone.conf` from Arch; start `rclone-gdrive`; verify `~/mnt/gdrive`.
- Affinity: launch `affinity-v3`; first run copies/builds its prefix. Keep the
  old AppImage prefix until this works.
- OBS: PipeWire screen capture + audio; no virtual camera/plugins yet.
- OpenRGB: check for two ENE DRAM controllers + IT5711; RAM inconsistency is
  expected to be investigated after the switch.
- CoolerControl: seeded `All Case Fans` profile; GUI remains the tuning
  surface. The flake ships 5.1.2 while the seed came from 5.0.1 — review
  `/var/lib/coolercontrol/config.toml` after first boot.
- DaVinci: opt-in; if RDNA4 OpenCL fails, keep Arch/Windows or revisit ROCm
  pinning later.
- Secure Boot: after Arch is wiped, lanzaboote + custom keys.
- Work through `docs/ROADMAP.md` parity checklist; one full NixOS workday
  before deleting Arch.

---

## Known traps / gotchas

- **Absolute flake input**: `msi-nix` is `git+file:///home/luka/code/msi-nix`;
  the path must exist in the ISO environment and on the target.
- **Placeholder hardware config**: never install with
  `modules/hosts/luka-workstation/hardware-configuration.nix` as committed;
  replace it with the generated file.
- **Device names swap**: select by size/model/PARTUUID, never `/dev/nvme0n1`.
- **Windows boot**: systemd-boot cannot read another ESP; it uses the EDK2 shell
  handle (`windows.<name>.efiDeviceHandle`). `FS1` is a placeholder until
  `map -c` is run.
- **Secure Boot is off** during the trial; do not enable it until the switch.
- **DaVinci source fetch** currently fails at the vendor server; don’t let it
  block the install.
- **Affinity first build** is large; use the cache/substituter and cap cores
  (`--cores 4 --max-jobs 1`) to keep the desktop responsive.
- **Backup password**: losing `~/.config/restic/luka-workstation.pass` makes the
  Drive backup unusable. Keep it off-machine.
- **OpenRGB root vs user service**: the NixOS module’s root service is disabled;
  the user service needs the profiles in `~/.config/OpenRGB`, not
  `/var/lib/OpenRGB`.
- **rclone client ID**: the shared rclone client is being retired; the remote
  now has a personal client ID. Re-run `rclone config reconnect gdrive:` if
  auth fails.

---

## How to resume on the MacBook

1. `cd ~/nixos-config && git pull` (this document is committed/pushed).
2. Read this file and `docs/WORKSTATION.md` before acting. The imported
   OpenCode session is incomplete; don’t rely on its missing attachments.
3. The Mac agent is **not** on the target machine. The user runs installer
   commands and pastes outputs, unless SSH is enabled on the ISO.
4. If remote execution is wanted, on the ISO:
   ```sh
   sudo -i
   passwd
   systemctl start sshd
   ip -brief address
   ```
   From the Mac: `ssh root@<installer-ip>`.
5. Resume at: boot Ventoy → minimal 26.05 UEFI → `lsblk` → confirm disks with
   the user before any destructive command.

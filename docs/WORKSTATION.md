# luka-workstation (Arch → NixOS)

The personal desktop: Ryzen 7 9800X3D, Radeon RX 9070 XT + Radeon 610M iGPU,
Gigabyte B850M GAMING X WIFI6E, 30 GiB RAM, RTL8852CE Wi-Fi/Bluetooth,
RTL8125 Ethernet, IT8696 fan controller.

Current stage: **dual-boot trial**. Arch stays on `nvme0n1` until NixOS has
passed a full workday and the creative stack is proven; then `nvme0n1` is wiped
and NixOS takes the whole disk. Windows stays on `nvme1n1` throughout.

## Layout

- `modules/hosts/luka-workstation/` — host entry, hardware (`hardware.nix`),
  generated filesystems (`hardware-configuration.nix`, a placeholder until the
  install), OpenRGB/CoolerControl seed files.
- `modules/hosts/features/creative.nix` — Affinity, DaVinci, Discord, Slack,
  Spotify, VLC, OBS; the narrow unfree allow-list and the Affinity overlay.
- `modules/users/features/gdrive.nix` — rclone Drive mount and `gdrive-pin`.
- `modules/users/features/openrgb.nix` — user OpenRGB SDK server; the NixOS
  module still supplies udev/i2c/the package, but its root service is disabled.
- `scripts/arch-cleanup.sh`, `scripts/pre-nixos-backup.sh` — run before the
  disk is touched.

## Decisions

- **Dual boot, separate ESP.** Arch keeps its 512 MiB ESP + rEFInd. NixOS gets
  a new 1 GiB FAT32 ESP (`NIXBOOT`) and systemd-boot. Windows is on its own ESP
  on `nvme1n1`; systemd-boot reaches it through the EDK2 shell handle
  (`efiDeviceHandle`, currently the placeholder `FS1` — find the real value
  with `map -c` in the EDK2 shell and update the host).
- **LUKS2 + btrfs.** LUKS2 passphrase on the NixOS partition; btrfs subvolumes
  `@`, `@home`, `@nix` with zstd; the existing 4 GiB swap partition is reused.
  Secure Boot is deliberately deferred until after Arch is removed (lanzaboote
  + custom keys then).
- **Native apps, no Flatpak.** Slack, Spotify, Discord, VLC, Ghostty, OBS,
  DaVinci and Zen all have native packages/flakes. Affinity comes from
  `mrshmllow/affinity-nix` (Wine prefix built in Nix, unfree, vendor installer,
  binary cache). Flatpak only if something is genuinely unpackaged later.
- **DaVinci is opt-in and a known risk.** nixpkgs 26.05 ships ROCm 7.2.3,
  which is the version that breaks Resolve on RDNA4 (nixpkgs issue #481483).
  Keep Arch or Windows available for Resolve until the GPU/OpenCL stack is
  proven; do not block the NixOS switch on it. The package is disabled by
  default (`my.creative.davinciResolve = true` to install it) because the
  nixpkgs 20.3.2 source fetch currently fails before the build starts.
- **OpenRGB/CoolerControl.** OpenRGB runs as the user (the system module still
  provides udev/i2c and disables its root service); the server owns `true-white`
  and reads the profiles from `~/.config/OpenRGB`. The CoolerControl
  `config.toml`/`overrides.toml` are seeded from
  `modules/hosts/luka-workstation/files/`. CoolerControl comes from
  `Daaboulex/coolercontrol-nix` (5.1.2; nixpkgs is on 4.3.0). RAM detection is
  known to be inconsistent and is deliberately not retried yet; `colourme`’s
  `openrgb -c ...` hook keeps working against the local server.
- **Google Drive.** `rclone mount` with a full VFS cache (currently 30 GiB,
  configurable under `my.gdrive`), not the old cache-less mount. `gdrive-pin`
  copies selected paths to `~/GoogleDrive-offline` for guaranteed offline use.
  The OAuth config stays in `~/.config/rclone/rclone.conf`, copied manually.
- **Backups.** restic to `rclone:gdrive:backups/luka-workstation`, password at
  `~/.config/restic/luka-workstation.pass` (never committed). Browser profiles
  are mostly skipped; Mozilla sync covers them.

## Validation (2026-11-23)

Built on the Arch workstation, not installed yet:

- `nix flake check --no-build`: passes for `luka-nixos-test` and
  `luka-workstation`.
- Home Manager generation for `luka-workstation`: builds.
- Full `luka-workstation` system: builds; closure ≈ 19.4 GiB.
- `affinity-v3`: builds; ≈ 6.2 GiB including the Wine/prefix closure.
- `coolercontrold` 5.1.2, Slack, Discord, Spotify, OBS: build.
- DaVinci Resolve: source fetch fails (vendor server); opt-in and unverified.
- OpenRGB, CoolerControl, gdrive, Tailscale, MSI systemd units: configured,
  not yet exercised on the real hardware.

Backup and snapshots:

- restic snapshot `12d1374a` (`pre-nixos`, 36.5 GiB, ~135k files) in
  `rclone:gdrive:backups/luka-workstation`; password in
  `~/.config/restic/luka-workstation.pass`.
- `restic check --read-data-subset=1%`: no errors.
- Restored `nixos-config/flake.nix` from the snapshot and compared it: match.
- Snapper keeps `1`, `1157`, `2533`, `2535`, `3124`–`3127` and
  `3128 Pre NixOS install`; all older timeline/package snapshots are deleted.
- `/home` has ~187 GiB free. The paru cache and DaVinci AUR build tree are
  intentionally retained for now.

## Install runbook (when ready)

> **Device names can swap between boots.** The Arch disk is the ~477 GiB WD
> (`nvme1n1` at the time of writing); Windows is the 3.6 TB Samsung
> (`nvme0n1`). Always identify by `SIZE`/`MODEL`/`PARTUUID`, never by the
> `nvmeXn1` name alone.

### 1. Preflight

- ISO: `~/Downloads/nixos-minimal-26.05.11045.774debe7a0d1-x86_64-linux.iso`
  (SHA-256 `81fdbaa462f15a2eb36b4c6a9e3b8d3430b847d9bf63dda36cb8456632a4403b`,
  matches the release). Write it to a USB stick (≥ 2 GiB) with
  `dd if=... of=/dev/sdX bs=4M status=progress oflag=sync`; verify the target
  with `lsblk` before pressing Enter.
- Windows: disable Fast Startup (and note any BitLocker recovery key) even
  though the Windows disk is not being repartitioned.
- Re-run the backup immediately before shrinking:
  `nix shell nixpkgs#restic nixpkgs#rclone -c ./scripts/pre-nixos-backup.sh`.
- Snapper already has `3128 Pre NixOS install`; create a new one if files
  change after it.

### 2. Boot the ISO and identify the disks

```sh
lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL,PARTUUID,MOUNTPOINTS
```

Set `ARCH_DISK` to the ~477 GiB disk and `WINDOWS_DISK` to the 3.6 TB disk.
Do not touch `WINDOWS_DISK`.

```sh
ARCH_DISK=/dev/nvme1n1   # VERIFY: 476.9G WD, btrfs @ + swap + vfat
WINDOWS_DISK=/dev/nvme0n1 # 3.6T Samsung; do not modify
```

### 3. Shrink Arch and create the NixOS partitions

Shrink the btrfs filesystem first (the ISO is not running Arch, so this is
safe):

```sh
mkdir -p /mnt/arch
mount -o subvolid=5 "${ARCH_DISK}p3" /mnt/arch
btrfs filesystem usage /mnt/arch
btrfs filesystem resize -120G /mnt/arch
btrfs filesystem usage /mnt/arch
umount /mnt/arch
```

Then shrink the partition and add a 1 GiB ESP + the rest as the LUKS root.
The arithmetic below works in MiB and assumes the existing Arch partitions are
1–3; confirm with `parted -s "$ARCH_DISK" unit MiB print` first.

```sh
read -r START END < <(
  parted -m -s "$ARCH_DISK" unit MiB print |
    awk -F: '$1==3 {printf "%.0f %.0f\n", $2, $3}'
)
NEWEND=$((END - 120*1024))          # shrink partition by 120 GiB
echo "p3: $START..$END MiB -> $NEWEND MiB"
parted -s "$ARCH_DISK" unit MiB resizepart 3 "${NEWEND}MiB"
parted -s "$ARCH_DISK" unit MiB mkpart NIXBOOT fat32 "${NEWEND}MiB" "$((NEWEND+1024))MiB"
parted -s "$ARCH_DISK" set 4 esp on
parted -s "$ARCH_DISK" unit MiB mkpart NIXROOT "$((NEWEND+1024))MiB" 100%
partprobe "$ARCH_DISK"
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTUUID "$ARCH_DISK"
```

If the numbering is not 1–3, replace `3` in the `parted` commands and the
`4` in `set 4 esp on` with the actual Arch root and new ESP numbers.

Create the filesystems:

```sh
mkfs.fat -F 32 -n NIXBOOT "${ARCH_DISK}p4"
cryptsetup luksFormat --type luks2 --label NIXROOT "${ARCH_DISK}p5"
cryptsetup open "${ARCH_DISK}p5" nixos
mkfs.btrfs -L nixos /dev/mapper/nixos

mount /dev/mapper/nixos /mnt
btrfs subvolume create /mnt/@ /mnt/@home /mnt/@nix
umount /mnt

mount -o subvol=@,compress=zstd /dev/mapper/nixos /mnt
mkdir -p /mnt/home /mnt/nix /mnt/boot
mount -o subvol=@home,compress=zstd /dev/mapper/nixos /mnt/home
mount -o subvol=@nix,compress=zstd,noatime /dev/mapper/nixos /mnt/nix
mount "${ARCH_DISK}p4" /mnt/boot
swapon "${ARCH_DISK}p2"   # reuse Arch's 4 GiB swap
```

### 4. Copy the config and generate hardware files

```sh
# Copy the repo + the MSI overlay from the Arch @home subvolume.
mkdir -p /mnt/arch
mount -o ro,subvol=@home "${ARCH_DISK}p3" /mnt/arch
mkdir -p /mnt/home/luka /mnt/home/luka/code /home/luka/code
cp -a /mnt/arch/luka/nixos-config /mnt/home/luka/
cp -a /mnt/arch/luka/code/msi-nix /mnt/home/luka/code/
cp -a /mnt/arch/luka/code/msi-nix /home/luka/code/   # flake input path during install
umount /mnt/arch

nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix \
   /mnt/home/luka/nixos-config/modules/hosts/luka-workstation/hardware-configuration.nix
```

The generated file must contain the new LUKS device and the `/`, `/home`,
`/nix` and `/boot` mounts. Check it before installing.

### 5. Install

```sh
nixos-install --flake /mnt/home/luka/nixos-config#luka-workstation \
  --option extra-substituters https://cache.forall.systems \
  --option extra-trusted-public-keys 'cache.forall.systems:5PmD7QO4MSF8YgyRZtkSGXRDo96H3bybIf2SsQh8ScI='
```

The MSI overlay must be at `/home/luka/code/msi-nix` in the **ISO** environment
for the flake input to evaluate; the copy above handles that. The installed
system gets `/mnt/home/luka/code/msi-nix`; clone/copy the rest of `~/code/msi`
after first boot.

### 6. First boot and Windows entry

- Log in as `luka` (the configured password) or use root to reset it.
- Open the EDK2 shell entry, run `map -c`, and find the Windows ESP
  (`ls FSx:\EFI\Microsoft\Boot\bootmgfw.efi`).
- Set `boot.loader.systemd-boot.windows."Windows".efiDeviceHandle` in
  `modules/hosts/luka-workstation/default.nix`, then
  `sudo nixos-rebuild switch --flake ~/nixos-config#luka-workstation`.
- Until the handle is set, use the firmware boot menu for Windows.

### 7. Post-install

## Post-install checks

- `tailscale up` (auth is manual; state is not in the store).
- Copy `~/.config/rclone/rclone.conf` from the old machine, then
  `systemctl --user start rclone-gdrive`; check `~/mnt/gdrive`.
- Affinity: `affinity-v3` first launch builds/copies its prefix; test a file
  and the plugin loader. Keep the old Arch AppImage prefix until this works.
- OBS: PipeWire screen capture + audio; no virtual camera/plugins yet.
- OpenRGB: check that the two ENE DRAM controllers and the IT5711 are present;
  the RAM inconsistency is expected to be investigated after the switch.
- CoolerControl: the seeded `All Case Fans` profile should apply on boot
  (fan1/fan2; fan3/fan5 default); GUI remains the tuning surface.
- DaVinci: try `davinci-resolve` and check Preferences → Memory/GPU; if RDNA4
  OpenCL still fails, use the Arch/Windows fallback. Revisit ROCm pinning later.
- Secure Boot: deferred; plan is lanzaboote with custom keys after Arch is gone.

## Known risks / open items

- Resolve on RDNA4 with ROCm 7.2.x (see above). The nixpkgs 20.3.2 source
  fetch failed on 2026-11-23 (vendor server 503/URL rejection), so the package
  is not built yet; retry before concluding anything about ROCm.
- Affinity on Wine is best-effort; sign-in/WebView2 pages may not work. Its
  first Nix build is large (Wine + prefix + winetricks); use the
  `cache.forall.systems` substituter configured in the host.
- OpenRGB RAM detection is inconsistent; no retry service yet by choice.
- The 1 GiB NixOS ESP holds systemd-boot + kernels; keep
  `configurationLimit` modest (currently 10).
- The Windows `efiDeviceHandle` is a placeholder until `map -c` is run.
- The CoolerControl seed is 5.0.1-shaped; the flake ships 5.1.2. It should
  migrate, but review `/var/lib/coolercontrol/config.toml` after first boot.

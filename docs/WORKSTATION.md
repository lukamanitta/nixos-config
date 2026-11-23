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

## Install runbook (when ready)

1. **Back up first.** `./scripts/pre-nixos-backup.sh`; verify the snapshot and
   keep the restic password somewhere off-machine.
2. **Free space.** `./scripts/arch-cleanup.sh` (dry run), then `--apply`.
   Review the snapper list and delete old timeline snapshots manually. Keep a
   recent snapshot and one taken just before partitioning. The script keeps the
   DaVinci AUR build tree by default (pass `--davinci-build` only once Resolve
   is proven on NixOS).
3. **Shrink Arch, create NixOS.** From the Arch live system (not the running
   root), shrink `nvme0n1p3` to free ~100 GiB, then create:
   - 1 GiB FAT32 ESP, label `NIXBOOT`
   - the rest as the NixOS partition, then LUKS2 (`cryptsetup luksFormat`)
   - btrfs inside the LUKS container with `@`, `@home`, `@nix`
4. **Generate hardware config.** Boot the NixOS ISO, mount the new layout under
   `/mnt`, then `nixos-generate-config --root /mnt` and replace the placeholder
   `modules/hosts/luka-workstation/hardware-configuration.nix`. The LUKS device
   is declared there (`boot.initrd.luks.devices.nixos`).
5. **Install.** `nixos-install --flake /mnt/home/luka/nixos-config#luka-workstation`.
   The system is added to the firmware boot menu by
   `boot.loader.efi.canTouchEfiVariables`.
6. **Windows entry.** Boot the NixOS system once, open the EDK2 shell entry,
   run `map -c`, identify the Windows ESP, and set
   `boot.loader.systemd-boot.windows."Windows".efiDeviceHandle` accordingly;
   rebuild and reboot. Until then, use the firmware boot menu for Windows.
7. **Post-install.** See below.

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

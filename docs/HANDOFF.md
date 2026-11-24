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
- **The trial is going well.** CoolerControl reads the IT8696 and fan curves
  work, Tailscale is up, and Affinity launches.
- **The desktop is LiquoRice** (Quickshell) on the workstation; LitheDE stays
  as the fallback via `my.desktops.environment`. Per-monitor workspaces are
  pinned (1/3/5/7/9 on DP-2, 2/4/6/8/10 on HDMI-A-2).
- **colourme drives every app colour**: Hyprland, Ghostty, Quickshell, Zen
  (live userChrome reload), Neovim and the wallpaper. Wallpapers live in
  `~/dotfiles/wallpaper/.wallpaper` (symlinked at `~/.wallpaper`) and go
  through waypaper + hyprpaper; the lock screen reads the same state.
- **Hyprland 0.55.4 carries a local backport** for layer-surface keyboard
  focus (upstream fix is 0.56.0); see the troubleshooting entry and the patch
  header. Remove both when nixpkgs catches up.
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

## Not verified yet

- Windows actually booting from the systemd-boot menu.
- Arch booting via rEFInd after the GPT conversion (the fallback is only
  theoretical until it is tried).
- Affinity opening a document and its plugin loader (it launches).
- OBS capture; OpenRGB (`true-white`, ENE DRAM controllers + IT5711).
- `rclone-gdrive` at `~/mnt/gdrive` and `gdrive-pin`.
- Wi-Fi/Bluetooth on NixOS.
- DaVinci Resolve (opt-in; RDNA4 + ROCm 7.2.x remains unproven).
- Colour seams on the disposable VM (they are verified on the workstation).

## Next actions in order

1. Work through the "Not verified yet" list; record failures in the
   troubleshooting doc rather than fixing them silently.
2. LiquoRice polish: toolkit theming (GTK/Qt/icons), the in-pill polkit prompt,
   and vendoring the wallpapers so the desktop no longer depends on the
   `~/dotfiles` checkout.
3. Do a full NixOS workday. Keep Arch bootable until it passes.
4. Copy the restic password and `rclone.conf` **off the WD disk** — they are the
   only things the removal procedure cannot recreate.
5. Then follow [WORKSTATION-ARCH-REMOVAL.md](./WORKSTATION-ARCH-REMOVAL.md)
   path A (re-layout + reinstall + restore). Secure Boot comes after that.

## Repo state at handoff

- `hardware-configuration.nix` for this host is now the generated file, committed.
- `gh.nix` disables `xdg.configFile."gh/config.yml"` so `gh` can write it.
- `hardware.nix` has `acpi_enforce_resources=lax` and
  `boot.extraModulePackages = [ config.boot.kernelPackages.it87 ]` (`672069b`).
- `default.nix` has `efiDeviceHandle = "FS0"`.
- Desktop: LiquoRice active, pinned workspaces, pill Logout, hyprpolkitagent,
  dark scheme preference, Roboto Mono vendored, Neovim config in
  `configs/nvim`, colour seams for Quickshell/Zen/Neovim/wallpaper.
- Custom patch: `modules/hosts/features/patches/hyprland-focus-restore.patch`
  plus the overlay in `modules/hosts/features/hyprland.nix`; remove with
  nixpkgs Hyprland 0.56+.
- The HDMI Arzopa panel is capped at 114.7 Hz with a modeline (the 144/120 Hz
  EDID modes drop out; see troubleshooting).
- Runtime paths owned by activation (not in git): `~/.config/nvim`,
  `~/.wallpaper`, `~/.config/waypaper/wallpaper.ini`,
  `~/.local/state/colourme/*`.
- Docs: this file, `WORKSTATION.md`, `WORKSTATION-TROUBLESHOOTING.md`,
  `WORKSTATION-ARCH-REMOVAL.md`, `DECISIONS.md` D45–D49, `ROADMAP.md`,
  `THEME-PIPELINE.md`.

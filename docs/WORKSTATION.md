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
| p4 | 748562432–750659583 | 1 GiB | vfat label `NIXBOOT`, PARTUUID `ec04e73a-e98c-4087-b20b-0d4276580eb8`, fs UUID `261B-9CAD` | NixOS ESP, Limine. |
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

- The NixOS ESP (p4) is owned by **Limine**; the firmware entry is labelled
  **`Limine`**. The menu is deliberately **monochrome and minimal**: the
  black-and-white `files/limine/mac-1.jpg` cropped to fill 16:9, a
  white-on-black menu panel, no branding and hidden key hints. It waits **10
  s**, keeps **5** generations (`boot.loader.limine.maxGenerations`), and
  **remembers the last booted entry** (`remember_last_entry`). Booting Windows
  and rebooting therefore preselects Windows.
- A NixOS rebuild must still win over "last booted": activation rewrites
  Limine's `LimineLastBootedEntry` EFI variable to the new generation.
  `nixos-rebuild switch` does this; `nixos-rebuild boot` does **not** run
  activation, so after `boot` select the new generation once.
- **Secure Boot is configured** (and is switched on by the first
  `nixos-rebuild boot` + reboot). `sbctl` keys live in `/var/lib/sbctl` (inside
  the encrypted root); Limine is signed with them and its config BLAKE2b hash is
  enrolled into the binary. Microsoft and firmware built-in keys are kept, so
  Windows, the GPU option ROMs and firmware capsules keep loading. Limine
  verifies kernels/initrds by hash added at install time; kernel modules are
  not signed and the NixOS kernel has no lockdown LSM, which is what lets the
  out-of-tree `it87` fan driver load.
- Windows has its own ESP on the Samsung NVMe. Limine chainloads it directly by
  GPT partition GUID
  (`4427216c-77f0-4027-884d-1e394b40e929:/EFI/Microsoft/Boot/BOOTMGFW.EFI`);
  the firmware verifies its Microsoft signature. The old systemd-boot
  `efiDeviceHandle = "FS0"` and the unsigned EDK2 shell are no longer used.
- Arch still boots through rEFInd on p1, but rEFInd is **unsigned**: with
  Secure Boot on it will not start. To use the fallback, temporarily disable
  Secure Boot in firmware (Security → Secure Boot), boot Arch, then turn it
  back on. Do not clear the keys.
- TPM2 auto-unlock is covered under "Filesystem/encryption".
- **Plymouth** (`breeze` theme) owns the screen from the kernel handoff until
  userspace is up; `quiet` + `loglevel=3` keep the journal off the console.
- There is **no display manager**. getty autologins `luka` on tty1 only, the
  login shell execs Hyprland, and LiquoRice locks immediately, so the
  Quickshell lock surface is the login screen. Logout returns to it. tty2–6
  keep a normal password prompt, so the lock cannot be bypassed with
  Ctrl+Alt+F2.
- Recovery from a broken Secure Boot change: enter firmware setup (Del at POST,
  or `systemctl reboot --firmware-setup` from a working system) and disable
  Secure Boot. Clearing keys is only safe if `/var/lib/sbctl` has been backed
  up; without it, regenerating keys means re-enrolling and re-signing.
- Once Limine has booted successfully, the stale systemd-boot artefacts and
  NVRAM entry can be removed to free the ESP and avoid selecting an unsigned
  loader: `sudo rm -rf /boot/EFI/systemd /boot/EFI/nixos
  /boot/EFI/edk2-uefi-shell /boot/loader` and `sudo efibootmgr -b 0003 -B`
  (check the number with `efibootmgr -v`). Keep the rEFInd entry until Arch is
  removed.


## Filesystem/encryption decisions as installed

- LUKS2 with **two keyslots**: the original passphrase (US keyboard layout at
  the initrd prompt) and a **TPM2 keyslot bound to PCR 7**. The TPM2 slot is
  what makes boot passwordless; the passphrase slot is the recovery path. If a
  firmware update, key change or Secure Boot toggle changes PCR 7, the TPM
  unseal fails and the passphrase prompt returns. Re-enroll after verifying
  Secure Boot is on:

  ```sh
  sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 \
    /dev/disk/by-uuid/b6191a65-7b50-4a79-8865-89dc8d7b7332
  ```

  To replace a stale TPM2 slot, add `--wipe-slot=tpm2` (never `--wipe-slot=0`,
  which is the passphrase). No recovery-key keyslot was added beyond the
  passphrase; losing the passphrase still loses the disk.
- btrfs `@`, `@home`, `@nix` with `compress=zstd`; `/nix` also `noatime`.
- `hardware-configuration.nix` was generated by `nixos-generate-config` on the
  installed system. It names the LUKS device `nixos` (from the mapper name) and
  references it as `/dev/disk/by-uuid/b6191a65-…`. It does **not** set
  `allowDiscards`.
- Swap is Arch's plain p2. No hibernation.
- `time.hardwareClockInLocalTime = true` for the Windows dual boot.

## Repo map (host-specific)

- `modules/hosts/luka-workstation/default.nix` — hostname, MSI, Tailscale,
  OpenRGB (root service disabled), CoolerControl, Bluetooth, Limine +
  Secure Boot, Windows GUID entry, TPM2/Plymouth, tty1 autologin, generation
  retention, RTC-in-local-time, Affinity substituter, Home Manager wiring.
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
alone leaves the running kernel as it was. `switch` also updates Limine's
remembered entry to the new generation; `boot` does not.

Secure Boot / TPM day-2 checks:

```sh
sudo sbctl status                  # Secure Boot enabled? keys present?
sudo sbctl verify                  # is the Limine binary signed?
sudo bootctl status                # firmware/SB/TPM view (bootctl still works)
sudo efibootmgr -v                 # NixOS entry is "Limine", Windows still there
df -h /boot                        # ESP headroom; 5 generations max
```

If Secure Boot keys are ever rotated or firmware updates change PCR 7, the TPM
prompt disappears and the passphrase is asked for; re-enroll with the command
in "Filesystem/encryption". Back `/var/lib/sbctl` up before reinstalling or
clearing firmware keys.

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
- `it87` loads against the IT8696 via the out-of-tree module (committed in
  `672069b`); CoolerControl reads the Super I/O and **fan curves work**.
- `gh` can write its own `config.yml`; authentication works.
- Tailscale is up.
- Affinity launches.

Boot/login changes made on 2026-11-27 (see D53–D56), not yet booted:

- systemd-boot replaced by Limine with a 10 s monochrome menu, 5 generations
  and `remember_last_entry`; the Windows entry chainloads by GPT partition GUID.
- Secure Boot keys generated/enrolled, Limine signed, config hash enrolled.
- Plymouth `breeze` + `quiet`/`loglevel=3`.
- TPM2 keyslot prepared in config; **enrollment is still manual after the
  first Secure Boot boot** (see "Filesystem/encryption").
- greetd/tuigreet removed on this host; tty1 autologin + Quickshell lock as
  the login UI.
- `nix.gc` weekly at 14 days; `limine.maxGenerations = 5`.

Not yet verified — do these before declaring the trial passed:

- [ ] Reboot into Limine with Secure Boot enabled; `sbctl status` says
      `Secure Boot: enabled`, `sbctl verify` passes.
- [ ] `systemd-cryptenroll` TPM2 keyslot enrolled and a reboot unlocks the
      root with no passphrase.
- [ ] Windows boots from Limine; reboot back and confirm Windows is
      preselected (remember-last), then a `nixos-rebuild switch` makes the new
      generation preselected instead.
- [ ] Arch still boots via rEFInd from the firmware menu **after temporarily
      disabling Secure Boot** (rEFInd is unsigned).
- [ ] Plymouth splash, tty1 autologin, Quickshell lock screen, and logout
      returning to the lock screen.
- [ ] Affinity opens a document and the plugin loader works (it launches).
- [ ] OBS: PipeWire screen capture + audio.
- [ ] OpenRGB: `true-white` loads; two ENE DRAM controllers + IT5711 visible
      (RAM detection is known-flaky and deliberately not chased).
- [ ] CoolerControl seed review: `All Case Fans` (fan1/fan2) is what you want,
      but the seed is 5.0.1-shaped against a 5.1.2 daemon, so glance at
      `/var/lib/coolercontrol/config.toml`.
- [ ] `rclone-gdrive` mount at `~/mnt/gdrive`, and `gdrive-pin`.
- [ ] Wi-Fi (RTL8852CE) and Bluetooth pairing — both untested on NixOS.
- [ ] Monitor layout: `DP-2` at `0x0` (144 Hz) and `HDMI-A-2` at `0x1080`
      (114.7 Hz modeline; see
      [WORKSTATION-TROUBLESHOOTING.md](./WORKSTATION-TROUBLESHOOTING.md#arzopa-hdmi-signal-drops)).
- [ ] DaVinci Resolve: still opt-in (`my.creative.davinciResolve = true`) and
      still unproven on RDNA4 + ROCm 7.2.x.
- [ ] A full workday on NixOS, then plan Arch removal.

# luka-workstation — troubleshooting

Symptom-first notes from the 2026-11-24 install. Every entry is something that
actually happened on this machine, with the cause and the fix that worked.

| Symptom | Section |
|---|---|
| `parted resizepart` printed a data-loss warning but did nothing | [Shrink silently declined](#shrink-silently-declined) |
| `sgdisk -g` says the secondary table overlaps the last partition by 33 blocks | [GPT conversion refused](#gpt-conversion-refused) |
| `mkpart` fails / only four partitions possible | [MBR four-primary limit](#mbr-four-primary-limit) |
| `btrfs filesystem resize` fails with ENOSPC | [btrfs shrink ENOSPC](#btrfs-shrink-enospc) |
| Installed system boots but there is no "NixOS" firmware entry | [Boot entry named Linux Boot Manager](#boot-entry-named-linux-boot-manager) |
| systemd-boot's Windows entry errors out | [Windows entry / handle](#windows-entry--handle) |
| rEFInd/Arch is not in the systemd-boot menu | [Arch is in the firmware menu](#arch-is-in-the-firmware-menu) |
| `modprobe it87: No such device` | [it87 and the IT8696](#it87-and-the-it8696) |
| CoolerControl shows no fans | [it87 and the IT8696](#it87-and-the-it8696) |
| `gh auth login` fails with `read-only file system` | [gh config.yml is read-only](#gh-configyml-is-read-only) |
| `gh auth login` hangs after the browser says success | [gh login hangs](#gh-login-hangs) |
| Copied `~/.ssh` is empty | [SSH keys live in @ssh](#ssh-keys-live-in-ssh) |
| Files copied from Arch are group `1000` | [gid 100 vs 1000](#gid-100-vs-1000) |
| `nix flake check` fails on the Mac | [Flake evaluation on the Mac](#flake-evaluation-on-the-mac) |
| `/boot` fills up | [ESP size](#esp-size) |
| Rebuild seems to ignore a kernel parameter | [Kernel params need a reboot](#kernel-params-need-a-reboot) |
| HDMI monitor blanks and flashes its input overlay | [ARZOPA HDMI signal drops](#arzopa-hdmi-signal-drops) |

## Disk and partition work

### Device names swapped

`nvme0n1` and `nvme1n1` have swapped between boots on this machine, and the
kernel's `major:minor` numbers are unrelated to the names: during the install
the WD disk was `/dev/nvme1n1` while `blkid` reported its partition as
`PART_ENTRY_DISK="259:0"`.

Address disks only through `/dev/disk/by-id/`:

```sh
ARCH_DISK=/dev/disk/by-id/nvme-WDC_PC_SN720_SDAPNTW-512G-1006_190350802260
readlink -f "$ARCH_DISK"     # informational only; never reuse the result
lsblk -dno MODEL,SERIAL "$ARCH_DISK"
```

Identity of the WD disk: model contains `WDC PC SN720`, serial
`190350802260`, 476.94 GiB. Windows is the Samsung 3.6 TB
(`S7U9NJ0Y515764R`) and must not be touched.

### MBR four-primary limit

The WD disk shipped with Arch on an **msdos** label: `p1` ESP, `p2` swap, `p3`
root. MBR has four primary slots, so a plan of "shrink p3, add an ESP, add a
LUKS root" (five partitions) cannot run. The install converted the disk to GPT
with `sgdisk -g` after freeing space at the end, then created p4/p5. The
conversion is in [DECISIONS.md](./DECISIONS.md) D45.

### Shrink silently declined

`parted -s /dev/x unit MiB resizepart 3 365509MiB` prints

```
Warning: Shrinking a partition can cause data loss, are you sure you want to continue?
```

and, in script mode, answers **No**. There is no prompt and no error; the
partition table is unchanged. Do shrinking interactively (drop `-s`) and answer
`Yes`, then verify the end sector changed:

```sh
parted -m -s "$ARCH_DISK" unit s print | grep '^3:'
```

Creating partitions with `-s` is fine; only shrinking is affected.

### Partition end versus filesystem end

`END - 120*1024` MiB is not safe arithmetic. On this disk the runbook value
(`365506MiB` = sector 748556288) sat **688 sectors below** the shrunken btrfs
end (`748556976`), which would have truncated the filesystem. Compute from the
real number and round up:

```sh
START_S=$(parted -m -s "$ARCH_DISK" unit s print | awk -F: '$1==3{print $2}' | tr -d 's')
TOTAL_B=$(btrfs inspect-internal dump-super -f "${ARCH_DISK}-part3" | awk '/^total_bytes/{print $2}')
FS_END_S=$(( START_S + TOTAL_B/512 ))
END_MIB=$(( (FS_END_S + 2047)/2048 + 2 ))        # round up, keep a margin
[ $(( END_MIB*2048 )) -ge "$FS_END_S" ] || echo REFUSE
```

Installed values: p3 starts at sector 9439232 and ends at 748562431; the
filesystem ends at 748556976, i.e. 3 MiB inside the partition on purpose.

### btrfs shrink ENOSPC

`btrfs filesystem resize -120G` can fail even with free space reported, because
the last chunk may be allocated. On this disk there was only 4.4 GiB of
unallocated slack for a 120 GiB shrink, so it nearly failed.

Fallback, in order:

```sh
btrfs balance start -dusage=50 -musage=50 /mnt/arch   # slow, minutes
btrfs filesystem resize -120G /mnt/arch
```

Or shrink by less (`-100G`). The shrink is reversible with `+120G` until the
partition table is changed. Never hibernate Arch first: its cmdline carries
`resume=UUID=<btrfs-root> resume_offset=33105152`, and resizing a hibernated
filesystem loses the image.

### GPT conversion refused

```
Warning! secondary partition table overlaps the last partition by 33 blocks!
```

means the last partition still reaches the last sector, so the backup GPT (33
sectors) has nowhere to live. `sgdisk -g` aborts without writing. Resize the
last partition *first* (interactively, see above), verify its end is well below
`1000215182`, then convert. Confirm the outcome with `sgdisk -p`: p3 ends around
`748562431` and ~120 GiB is free.

`blkid -p` on a GPT partition prints `PART_ENTRY_*` fields even when no
filesystem exists. The absence of `TYPE=` is what means "empty".

## Install and boot

### Boot entry named Linux Boot Manager

`nixos-install` creates the systemd-boot NVRAM entry via `bootctl`, which
labels it **`Linux Boot Manager`**. Grepping `efibootmgr -v` for "nixos" finds
nothing and is not evidence of a failed install. Check `efibootmgr` for the
label, and `/boot/EFI/systemd/systemd-bootx64.efi` for the binary.

### Windows entry / handle

systemd-boot cannot read a second ESP, so `boot.loader.systemd-boot.windows`
chainloads Windows through the EDK2 shell handle
(`efiDeviceHandle`, currently `FS0`). To (re)discover it: choose the *UEFI
Shell* entry at the systemd-boot menu, then

```
map -r
map
ls FS0:\EFI\Microsoft\Boot\bootmgfw.efi
ls FS1:\EFI\Microsoft\Boot\bootmgfw.efi
```

The `FSx` whose path exists is the handle. Update
`modules/hosts/luka-workstation/default.nix` and
`sudo nixos-rebuild switch`. The mapping can shift when disks, USB devices, or
firmware settings change; if the menu entry starts erroring, rediscover it.
Firmware's own `Windows Boot Manager` entry always works as a fallback.

### Arch is in the firmware menu

rEFInd lives on Arch's ESP (p1) and is its own EFI application, so it appears
in the **motherboard boot menu** (F12), not in systemd-boot. Two identical
`rEFInd` NVRAM entries exist (`Boot0001`, `Boot0002`); either works. Without
the firmware menu, reach Arch from the EDK2 shell:
`FSx:\EFI\refind\refind_x64.efi`, where `FSx` is the 512 MiB Arch ESP.

### Kernel params need a reboot

`boot.kernelParams`, initrd contents, and `boot.extraModulePackages` only take
effect on the next boot. `nixos-rebuild switch` alone changes the next
generation, not the running kernel. Verify with `cat /proc/cmdline`.

### ESP size

p4 is 1 GiB with `configurationLimit = 10`. Each generation costs roughly
50–60 MiB (kernel + initrd), so 10 generations plus systemd-boot is tight. Check
`df -h /boot` after a few rebuilds and lower the limit if it climbs past ~70%.

## Displays

### ARZOPA HDMI signal drops

**Symptom:** the ARZOPA portable panel on `HDMI-A-2` (RX 9070 XT) blacks out
for about a second and returns showing its "HDMI" input overlay. At 144 Hz it
happened several times a minute; at 120 Hz it still happened, just less often.

**Diagnosis:** nothing appears host-side during a dropout. `journalctl -k`
logs no link-training line, `udevadm monitor --udev --subsystem-match=drm`
emits no event, and `status` / `enabled` / `dpms` under
`/sys/class/drm/card1-HDMI-A-2/` never change. The GPU keeps the pipe enabled
— the sink loses sync and re-acquires. Arch behaved the same way, so this is
not the NixOS kernel, amdgpu version, or Hyprland. The panel's EDID declares a
360 MHz TMDS limit and its 144 Hz mode already runs at 332.77 MHz reduced
blanking (92 % of that limit), so the link is marginal rather than broken.

**Fix:** pin a modeline below the failing clock in `my.hyprland.monitors`
(`modules/hosts/luka-workstation/default.nix`). Measured 2026-11-24:

| clock | refresh | result |
|---|---|---|
| 332.77 MHz | 144 Hz (EDID) | drops within a minute |
| 297.00 MHz | 120 Hz (EDID) | drops within minutes |
| 265.75 MHz | 114.7 Hz | stable |

The modeline reuses the panel's own reduced-blanking geometry (2080×1111,
taken from its 144 Hz DTD):

```nix
mode = "modeline 265.75 1920 1968 2000 2080 1080 1083 1088 1111 +hsync +vsync";
```

Clock = 2080 × 1111 × refresh; nothing above ~265 MHz has held. The modeline
is specific to this panel, so remove it if the display is replaced.

**Open:** the 3 m JSAUX mini-HDMI→HDMI cable has only the owner's Windows
recollection as evidence that it can carry 144 Hz, so a shorter certified
cable may still allow a higher rate.

## it87 and the IT8696

**Symptom:** `modprobe: ERROR: could not insert 'it87': No such device`, and
CoolerControl reports no fans.

Two independent causes, both present here:

1. **ACPI resource conflict.** Gigabyte firmware claims the Super I/O region.
   Arch worked only because its cmdline had `acpi_enforce_resources=lax`.
   Without it, the in-tree driver refuses to bind:

   ```nix
   boot.kernelParams = [ "acpi_enforce_resources=lax" ];
   ```

2. **The in-tree driver does not support the IT8696E.** Mainline `it87` covers
   up to IT8689E/IT8728F. Nixpkgs ships Frank Crawford's out-of-tree driver as
   `config.boot.kernelPackages.it87` (`pkgs/os-specific/linux/it87`), which
   does:

   ```nix
   { config, ... }:
   {
     boot.extraModulePackages = [ config.boot.kernelPackages.it87 ];
     boot.kernelModules = [ "it87" ];
   }
   ```

   Both trees provide `hwmon/it87.ko`, so the build can fail with a collision.
   Let the extra package win:

   ```nix
   { config, pkgs, lib, ... }:
   {
     system.modulesTree = lib.mkForce [
       ((pkgs.aggregateModules (
         [ config.boot.kernelPackages.kernel.modules ] ++ config.boot.extraModulePackages
       )).overrideAttrs { ignoreCollisions = true; })
     ];
   }
   ```

**Verify:**

```sh
cat /proc/cmdline            # acpi_enforce_resources=lax present
modinfo -n it87              # resolves under /run/current-system/kernel-modules
sudo modprobe -v it87
grep . /sys/class/hwmon/hwmon*/name
sensors | grep -iE 'fan|temp'
```

**Committed state:** the package line lives in `hardware.nix` as of `672069b`,
and on this kernel/nixpkgs it built with no module collision, so the
`system.modulesTree` override above is **not** in use. Add it only if a build
actually fails with a duplicate `it87.ko`.

If the module loads but no `hwmon` device appears, do not guess `force_id`
values — wrong chip IDs scale voltages incorrectly. Record
`dmesg | grep -i it87` first.

## gh

### gh config.yml is read-only

`gh auth login` fails with
`open /home/luka/.config/gh/config.yml: read-only file system`.

home-manager's `programs.gh` **always** generates `gh/config.yml` as a
read-only `/nix/store` symlink (it wraps `{ version = "1"; } // settings`).
`hosts.yml` is only managed when `programs.gh.hosts` is set, so tokens are
fine; only `config.yml` is the problem. Disable that one generated file and let
`gh` own it:

```nix
# modules/users/features/gh.nix
xdg.configFile."gh/config.yml".enable = false;
```

Then `sudo nixos-rebuild switch`; activation removes the orphaned symlink.

### gh login hangs

The browser says "you're all set" and the terminal never returns. The OAuth
leg succeeded; the local leg is stuck, usually on a D-Bus secret service that
isn't running (common in a Hyprland/LitheDE session without gnome-keyring).
Check from a second terminal whether it actually worked (`gh auth status`), and
retry with plain-file storage:

```sh
gh auth login --insecure-storage --git-protocol ssh
ls -l ~/.config/gh/hosts.yml     # must be -rw-------
```

`--insecure-storage` means "token in a 0600 file inside the LUKS-encrypted
home" instead of a keyring. If it still hangs, `GH_DEBUG=api gh auth login`
shows whether it is waiting on `api.github.com` (network/proxy) or never gets
there (keyring).

Pushes never require `gh`: the remote can use SSH with the keys in `@home`.

## Files, users, other tools

### SSH keys live in @ssh

Arch keeps `~/.ssh` in its own subvolume `@ssh`, so mounting `subvol=@home` and
copying `luka/` yields an **empty** `.ssh`. Mount it explicitly:

```sh
mount -o ro,subvol=@ssh "${ARCH_DISK}-part3" /mnt/arch-ssh
```

On NixOS the keys were copied into `@home/luka/.ssh` and the subvolume was
**not** recreated (see [DECISIONS.md](./DECISIONS.md) D46). The directory must
be `0700` and owned by uid 1000 or SSH refuses it.

### gid 100 vs 1000

NixOS `isNormalUser` accounts are uid 1000, gid 100 (`users`). Arch files come
across as `1000:1000`. Ownership by uid is what matters; `chown -R 1000:100`
tidies the group if the numeric gid bothers anything.

### Flake evaluation on the Mac

`flake.nix` pins `msi-nix` to `git+file:///home/luka/code/msi-nix`, an absolute
path that does not exist on macOS, so every flake command fails there. Use:

```sh
nix flake check --override-input msi-nix path:~/code/msi-nix
```

On the machine and in the installer the path must exist as a git repo at the
pinned rev (`21732288b9700ed2dd9c283ad0c0defc6893db17`); `cp -a` preserves
`.git`, `git+file://` reads the committed tree only.

### CoolerControl seed version

`files/coolercontrol/config.toml` was taken from CoolerControl 5.0.1 while the
flake ships 5.1.2. The daemon migrates it, but review
`/var/lib/coolercontrol/config.toml` after the first start; the seed is copied
once and the daemon owns it afterwards. `All Case Fans` maps to fan1/fan2, with
fan3/fan5 on default.

### LUKS details

- Passphrase is typed with a **US layout** in the initrd.
- No recovery keyslot exists yet. Adding one (a keyfile on a USB stick, or a
  second passphrase) is the cheapest insurance and can be done live:
  `sudo cryptsetup luksAddKey /dev/disk/by-uuid/b6191a65-…`.
- `hardware-configuration.nix` does not set `allowDiscards`; TRIM does not pass
  through the container until that is added (needs a rebuild + reboot).
- The swap partition (Arch's p2) is **not** encrypted, so hibernation would
  write plaintext memory to disk. Hibernation is not configured.

### blkid is not a filesystem probe

`blkid -p` prints partition-table metadata for GPT partitions. Use
`blkid <dev>` (or check for `TYPE=`) when asking whether a filesystem exists.

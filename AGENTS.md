# Agent instructions

## Target machines

This repo configures two hosts:

- **`luka-workstation`** — the desktop (Ryzen 9800X3D, RX 9070 XT, Gigabyte
  B850M). Installed 2026-11-24: NixOS dual-boots with Arch still on the WD NVMe
  as a trial-period fallback, and Windows sits untouched on the second NVMe.
  Read `docs/WORKSTATION.md` before touching disks, boot entries, or hardware
  modules, and `docs/WORKSTATION-TROUBLESHOOTING.md` before debugging anything
  it covers — that host has already produced a long list of traps.
- **`luka-nixos-test`** — a disposable NixOS VM.

Before debugging a build or reading runtime state, check where you are:

```sh
hostname
```

- On `luka-workstation` or `luka-nixos-test`: live runtime files are valid
  evidence for that host.
- Anywhere else (usually macOS): debug from this repo only — `nix eval`,
  `nix flake check`, package sources in the Nix store, and the docs. Ask the
  user for machine output or SSH access when live state is genuinely needed.
  Flake evaluation on macOS additionally needs
  `--override-input msi-nix path:…`; see the troubleshooting doc.

Arch still exists on the workstation's WD disk during the trial and is booted
from the firmware menu (rEFInd). Treat Arch's dotfiles under `~/dotfiles` and
its live `~/.config` as a different system: evidence for Arch, not for NixOS.

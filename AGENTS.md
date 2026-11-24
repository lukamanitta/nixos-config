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

## Hyprland is Lua-configured

`modules/users/features/hyprland/default.nix` sets `configType = "lua"`, so the
live config (`~/.config/hypr/hyprland.lua`) and every runtime command use the
Lua API, not the legacy ini syntax. Two traps:

- `hyprctl keyword …` fails with `keyword can't work with non-legacy parsers`.
  Change settings at runtime with `hyprctl eval 'hl.config({ … })'`, then
  `hyprctl reload` if the change needs a config pass.
- `hyprctl dispatch exit` fails with
  `hl.dispatch: expected a dispatcher (e.g. hl.dsp.window.close())`. Dispatchers
  are Lua expressions: `hyprctl dispatch 'hl.dsp.exit()'`,
  `hyprctl dispatch 'hl.dsp.focus({ workspace = "1" })'`. To log out of the
  session, `hl.dsp.exit()` or `loginctl terminate-session "$XDG_SESSION_ID"`
  both work; the pill's power surface has a Logout tile as well.

Binds, monitor rules, workspace rules and window rules are generated as
`hl.bind` / `hl.monitor` / `hl.workspace_rule` / `hl.window_rule` entries; see
`modules/users/features/hyprland/` for the sources.

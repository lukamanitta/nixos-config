# Agent instructions

## Target machine check

This repo configures **`luka-nixos-test`**, a NixOS VM. The workstation you are
usually sitting at is **Arch** with dotfiles under `~/dotfiles`; its live
`~/.config`, `~/.local`, and system state are unrelated to the NixOS target.

Before debugging a build or reading runtime state, check where you are:

```sh
hostname
```

- On `luka-nixos-test`: live runtime files are valid evidence.
- Anywhere else: debug from this repo only — `nix eval`, `nix flake check`,
  package sources in the Nix store, and the docs. Ask the user for VM output or
  SSH access when live state is genuinely needed.

Treat the Arch workstation's dotfiles and live configs as a different system.

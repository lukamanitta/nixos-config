# Roadmap

Living plan for this NixOS configuration and the portability / dotfiles work
around it.

- **Strategy and sequencing live here.** Day-to-day actionable tasks live in
  Todoist; both are used for now, linked by theme name.
- **Organised lifecycle-first** (Now / Next / Later) because the stack is still
  new. This will shift toward theme/project organisation once it is settled.
- **Curated, bit-by-bit.** Only the dotfiles I actually use get ported, one at
  a time, validated on the disposable VM first.

---

## Guiding principles

- **Reproducible, but portable.** Nix augments my environment; anything that
  must also work on non-NixOS machines stays usable without it.
- **Host-agnostic modules, composed per host.** No feature module assumes a
  specific machine or user.
- **Validate on the test VM before the daily driver.** Nothing touches the main
  machine until its checklist passes.
- **Incremental.** Small, verifiable steps.
- **Secrets never enter git or the Nix store.**
- **Simple before clever.** Adopt dendritic / flake-parts only when a concrete
  need (a second real host) justifies it.

## Non-goals

- No blanket rewrite of configs into Nix. Any rewrite is gated on the non-Nix
  workflow spike (see [Portability](#portability)).
- No main-machine migration before the parity checklist passes.
- macOS + Home Manager standalone is **exploratory**: no deadline, no confirmed
  Mac target yet.
- No secrets in git or the Nix store.
- No GPU / gaming tuning in this effort.
- Not porting dormant dotfiles "for posterity".

---

## Now / Next / Later

### Now
- [x] Stabilise the test VM flake: host, Home Manager, lockfile, verified
      `hardware-configuration.nix`.
- [x] Multi-host-shaped module layout: split user identity from host-agnostic
      feature modules (`modules/hosts` / `modules/users`, `features/` on each
      side). See [DECISIONS.md](./DECISIONS.md).
- [ ] Dotfiles ↔ Home Manager symlink plumbing (`mkOutOfStoreSymlink`) validated
      on the VM.
- [ ] Port the core cross-cutting dotfiles subset (see
      [Dotfiles integration](#dotfiles-integration-hybrid)).
- [ ] Keep secrets untracked and symlinked.

### Next
- [ ] Desktop stack on the VM: Hyprland, Quickshell, mako, wofi, wallpaper,
      colourme.
- [ ] Dev environment: `nix develop` dev shells primary, `mise` fallback,
      retire `asdf`.
- [ ] AI agent parity: opencode + skills.
- [ ] Non-Nix workflow validation spike (dotfiles + HM standalone).

### Later
- [ ] Neovim composability: per-host tooling, then per-host plugins/config.
- [ ] Managed secrets: Bitwarden SSH agent / Secrets Manager.
- [ ] Config-artifact export: features **self-register** what (if anything) they
      own worth exporting, then generate a bundle on demand. Deferred until the
      real use cases are pinned down.
- [ ] Dendritic refactor — trigger: first real non-test host.
- [ ] Homelab nodes.
- [ ] Migrate the main machine to NixOS — gated by the parity checklist.

---

## Themes

### Foundation / flake architecture
- NixOS `26.05` (stable), Home Manager `release-26.05`, `neovim-nightly-overlay`.
- One host today (`luka-nixos-test`); modules kept multi-host-shaped from the
  start.
- Current layout:
  - `modules/hosts/<host>/` — machine-specific host config (+ hardware).
  - `modules/hosts/core.nix` — host-global settings.
  - `modules/hosts/features/` — host-agnostic system feature modules.
  - `modules/users/features/` — user / Home Manager feature modules.
  - `modules/users/<user>/` — per-user profile composing feature modules.
- [ ] Adopt `flake-parts` + `import-tree` (dendritic) once there are 2+ real
      hosts.

### Config artifacts / feature self-registration (deferred)
Idea: rather than a central dump that exports every generated file, each feature
module **declares** what it owns that is worth materialising as plain files —
for a stow-based dotfiles tree, sharing, or one-off generation. Not every
feature is a program or something that should be exported, so registration must
be opt-in per feature.

- Deferred — nail down the actual use cases first (shareable dotfiles? non-Nix
  bootstrap? one-off generation?).
- Likely lands naturally with the dendritic refactor, where features are
  self-registering modules. See [Dotfiles integration](#dotfiles-integration-hybrid).

### Dotfiles integration (hybrid)
Keep `~/dotfiles` (git, GNU stow) as the single source of truth; Nix symlinks it
in rather than rewriting it.

- Complex / mutable configs → symlinked from the dotfiles repo via
  `config.lib.file.mkOutOfStoreSymlink` (keeps them editable and OS-agnostic).
- Simple declarative configs → native Home Manager options.

In-scope subset (curated):

- **Cross-cutting:** `editorconfig`, `fish`, `fonts`, `git`, `ghostty`,
  `lazygit`, `nvim`, `starship`, `tmux`, `vim`, `yazi`, `colourme`.
- **Desktop-only:** `hypr`, `quickshell`, `mako`, `wofi`, `wallpaper`,
  `spicetify`.
- **Retiring:** `asdf` (see [Development environment](#development-environment)).
- Everything else stays dormant and unported.

### Desktop environment
Hyprland on Wayland, greetd + tuigreet, config generated by Home Manager
(`configType = "lua"`) and composed from Nix modules. A role interface
(`my.desktop.programs` / `my.desktop.services`) lets features provide defaults
and hosts/users override; a baseline `hyprland-ecosystem` feature gives a usable
out-of-the-box DE (hyprlauncher/hyprlock/hypridle/hyprpaper + waybar, with
minimal configs). Rationale and specifics: [DECISIONS.md](./DECISIONS.md) D3–D24.

- [x] Hyprland config generated from Nix (roles, binds, autostart, monitors).
- [x] Baseline ecosystem defaults + minimal configs.
- [ ] Quickshell feature: `programs.quickshell.configs` (`Pill`, `lockdaemon`)
      from `configs/quickshell/`, scripts as `writeShellApplication`, sets
      `statusBar`. See DECISIONS D19/D20.
- [ ] Clipboard feature: `clipboardPicker` + `clipboardWatcher`.
- [ ] Screenshots + scratch-terminal features (tool-specific binds).
- [ ] `colourme` theme pipeline — deferred (DECISIONS D18).
- [ ] Autologin + Quickshell lock-as-greeter — deferred (DECISIONS D23/D24).
- [ ] Hyprland stable for one week on the VM.

### Development environment
- [ ] Per-project `nix develop` dev shells as the primary mechanism.
- [ ] `mise` as the cross-platform fallback; retire `asdf` and `.tool-versions`.
- [ ] AI tooling parity (opencode + skills).
- Dev shells are the natural precursor to per-project dendritic modules.

### Neovim composability
Long-term intent: assemble Neovim per host — a **tool layer** (choose LSP servers
/ formatters / treesitter parsers so unnecessary ones aren't installed) plus an
optional **plugin / UI layer**.

- Base config stays symlinked from `dotfiles/nvim` (`vim.pack` based).
- Per-host tooling provided as Nix packages on `PATH`; per-host overrides via
  optional symlinked `lsp/` fragments.
- Native Home Manager Neovim rewrite is off the table unless the portability
  spike argues otherwise.

### Secrets
- Near term: secret files (API keys, etc.) live **untracked** inside the
  dotfiles tree and are symlinked like any other file — never read by Nix.
- [ ] Later: evaluate Bitwarden SSH agent (SSH keys) and Secrets Manager (API
      keys).

### Portability
Requirement: **the dotfiles repo stays independently usable without Nix** (stow
/ plain files reproduce the environment). Home Manager standalone on a non-NixOS
machine is an experiment, not a requirement.

- [ ] Spike: apply dotfiles + HM standalone on a non-NixOS user account / macOS.
- [ ] Use the spike's outcome to decide how much (if any) to rewrite into Nix.
- [ ] Keep dotfiles free of NixOS-only assumptions.

### Homelab / multi-host
Future: homelab nodes, most services as Docker containers, some multi-purpose
nodes (e.g. attached to TVs).

- [ ] Decision: NixOS vs a minimal distro for Docker-centric nodes.
- [ ] Decide service deployment approach (Docker Compose vs nixos-containers).
- [ ] Multi-purpose / TV nodes: declarative apps + kiosk config.
- Provides the **second host** that triggers the dendritic refactor.

### Main machine migration (Arch → NixOS)
Endgame, gated by the parity checklist below.

---

## Parity checklist (gate for the main machine)

- [ ] Terminal (ghostty/tmux/fish) at parity
- [ ] Editor + LSPs (Neovim) at parity
- [ ] AI agent setup (opencode + skills) at parity
- [ ] Browser
- [ ] Slack
- [ ] Tailscale
- [ ] Hyprland / Quickshell stable for one week
- [ ] colourme theme pipeline
- [ ] spicetify
- [ ] VPN
- [ ] Backups verified
- [ ] Data migration plan
- [ ] Documented rollback (keep Arch install / snapshots)

---

## Settled decisions

- Config lives in **`nixos-config`**; the roadmap tracks dotfiles work too,
  labelled with its repo path. Pointer added to `dotfiles/README.md`.
- **Hybrid** dotfiles: symlink complex configs, native Nix for declarative ones.
- Doc is **lifecycle-first** now, theme-based later.
- Tracking is **both** doc checkboxes and Todoist, for now.
- Secrets stay **out of git and the Nix store**.
- Dev tooling: `nix develop` + `mise`, retiring `asdf`.
- Modules are **multi-host-shaped now**, not later.
- macOS + HM standalone = exploratory.

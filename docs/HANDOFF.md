# Handoff — LitheDE (default desktop environment)

> Session handoff doc. Kept in-repo so it survives restarts. Safe to delete or
> replace once the work it describes is picked up.

Repo: `/home/luka/nixos-config` (branch `main`). Key commit: **`162f80c`**
"feat: add LitheDE default desktop environment". Run on the **NixOS test VM**
(`luka-nixos-test`); the machine you are likely sitting at (Arch / `~/dotfiles`)
is *not* the target — do not read that machine's `~/.config` to debug the NixOS
build.

## Orientation (read these first, do not duplicate their content)

- `docs/LITHEDE.md` — the design + status. Its **"Remaining follow-ups"**
  section already lists several open items (swaync `style.css`, hyprlauncher
  config/theme, Qt `qt6ct` colourme seam, network-joining UX, real
  traffic-light glyphs, icon/cursor theme-name verification, float formatting).
- `docs/DECISIONS.md` — D22 is superseded by **D29** (two peer DEs on a shared
  compositor base, `my.desktops.environment`), **D30** (mouse-first LitheDE),
  **D31** (vendored fonts + Adwaita shapes).
- `docs/ROADMAP.md` — "Desktop environment" section.
- `docs/THEME-PIPELINE.md` — **doc debt:** not yet updated for the GTK3/GTK4/
  waybar colourme seams added in D27's addendum.

Architecture recap: `modules/users/desktops/lithe/` holds the DE
(`default.nix` roles/packages/configs, `hyprland.nix` visual config,
`tokens.nix`, `toolkit.nix`, `panel.nix`, `controlcenter.nix`,
`windowcontrols.nix`). `modules/users/features/hyprland/` is the shared,
DE-agnostic compositor feature.

## Current focus (user-raised, this session)

### 1. hyprbars window buttons are missing
Observed: the **bars themselves render** (plugin loaded, bar styling applied),
but **no close/float/fullscreen buttons**. Implementation is
`modules/users/desktops/lithe/windowcontrols.nix`: at `hyprland.start` it runs a
chained `hyprctl plugin load … && hyprctl keyword 'plugin:hyprbars:<opt>' …`,
including three `hyprctl keyword 'plugin:hyprbars:hyprbars-button' 'rgb(..), 10, x, hyprctl dispatch killactive'`.

Why it was done this way: HM loads plugins in the `hyprland.start` hook, so the
documented Lua `hl.plugin.hyprbars.add_button` at config scope runs *before* the
plugin exists. Since bar options evidently applied but buttons did not, the
leading hypotheses are:
- `hyprbars-button` may only take effect when set at config-parse time (or
  before a window is mapped), not via `hyprctl keyword` after start.
- The `hyprbars-button` value/format via `hyprctl keyword` may be parsed
  differently than in-config.
- Keyword path may differ (verify with `hyprctl plugin list` and by setting one
  button by hand).

Next steps: reproduce on the VM, inspect `hyprctl plugin list` / logs, and try
one (or more) of: (a) a Lua `hl.on("hyprland.start", …)` callback that calls
`hl.plugin.hyprbars.add_button(...)` (ordering vs HM's own start command is the
risk); (b) find a way to load the plugin at config-parse time; (c) a chained
shell command that runs `hyprctl plugin load` then `hyprctl keyword` for
buttons, confirming the exact keyword string. Plugin package:
`pkgs.hyprlandPlugins.hyprbars` (store shows `hyprbars-0.55.0`).

### 2. hyprlauncher and hyprlock are unstyled
- **hyprlauncher `0.1.6`**: config is hyprlang found via
  `Hyprutils::Path::findConfig("hyprlauncher")`; known keys include
  `general:grab_focus`, `cache:enabled`, `finders:*` (`default_finder`,
  `desktop_prefix`, `desktop_icons`, `desktop_terminal`, …),
  `ui:window_size` (VEC2). **Theming follows the hyprtoolkit theme**
  (`libhyprtoolkit.so.5`, hyprtoolkit `0.5.4`) — i.e. *not* a per-app CSS file.
  Investigate how to point hyprtoolkit at the gruvbox/colourme palette (likely a
  hyprtoolkit config or env var), then generate it. Also add a minimal
  `hyprlauncher.conf` (config placement per D25).
- **hyprlock `0.9.5`**: currently a bare inline `hyprlock.conf` in
  `lithe/default.nix` (hardcoded `rgba(1a1b2aff)`). Theme it from the LitheDE
  tokens + colourme (hyprlock supports `$variables`/`source`; decide whether to
  generate the conf from Nix tokens or add a colourme seam).

### 3. Bar design: workspaces *and* taskbar is not cohesive
`lithe/panel.nix` currently shows `modules-left = custom/launcher, wlr/taskbar`,
`modules-center = hyprland/workspaces`, `modules-right = tray, clock,
custom/controlcenter`. The user finds "workspaces + per-app taskbar" redundant
and wants the bar to look "clean, professional, cohesive". This is a **design
decision** — treat it as such (see Suggesting skills below) before coding.
Options to weigh: drop `wlr/taskbar` (workspaces only), or replace `workspaces`
with a taskbar/dock, or a left "focused-window" pill only, etc. Capture the
outcome in `docs/LITHEDE.md`.

### 4. Icons are the literal macOS set, not the redesigned variant
`toolkit.nix` uses `pkgs.whitesur-icon-theme` with theme name `WhiteSur-dark`.
nixpkgs' derivation supports an override:
`pkgs.whitesur-icon-theme.override { alternativeIcons = true; }` (and
`boldPanelIcons = true` for bold panel icons) — that is the redesigned set the
user wants. Theme names remain `WhiteSur` / `WhiteSur-dark` / `WhiteSur-light`.
Cursor theme name is confirmed `WhiteSur-cursors` (`pkgs.whitesur-cursors`).

### 5. First-boot colourme race (may already be fine)
User saw `module 'theme.colourme' not found` on first login; it was **gone after
a restart**. Likely the activation seed/`hyprctl` timing. Worth confirming and,
if real, ensuring the theme file exists before the first Hyprland session.
(The colourme build-time render itself is healthy: reproduced locally with the
packaged tool — all six seams — and it exits 0.)

## Other backlog

- **New task (user):** add the user's **opencode skills/config to the opencode
  feature** (`modules/users/features/opencode.nix`). `~/dotfiles/opencode/`
  exists and `~/.config/opencode/skills/*` are installed on the machine.
- Already-listed follow-ups: see `docs/LITHEDE.md` § "Remaining follow-ups".

## Environment facts

- nixpkgs pinned in `flake.lock`; eval is offline-clean.
- Verify changes with: `nix flake check --no-build` (fast, catches option/
  package errors) and
  `nix eval --raw .#nixosConfigurations.luka-nixos-test.config.system.stateVersion`.
- Package names quirk: it's `pkgs.swaynotificationcenter` (binary `swaync`),
  `pkgs.whitesur-cursors`, `pkgs.qt6Packages.qt6ct` (renamed).
- `nix fmt <files>` formats with `nixfmt-rfc-style`.
- Before activating on a machine that still uses the dotfiles symlink:
  `stow -D fonts` so Nix can own `~/.local/share/fonts`.

## Suggested skills

- **grilling** — for task 3 (bar redesign) and any remaining design calls; this
  whole project was built by grilling the frontier of decisions.
- **customize-opencode** — for the opencode skills/config feature task.
- **writing-for-agents** — if updating `docs/LITHEDE.md`,
  `docs/DECISIONS.md`, or creating a new doc.
- **handoff** — again, when you finish, to pass the baton onward.

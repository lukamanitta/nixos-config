# Decisions

Architecture decision log. One entry per non-obvious choice, with the reasoning
so future-me (or another agent) doesn't relitigate it. Statuses: **settled**,
**open** (decision pending), **superseded**.

Grouped by area, not strictly chronological.

---

## Repository layout

### D1 — Everything under `modules/`, dendritic-shaped (settled)
`modules/hosts/<host>/` for machines, `modules/hosts/features/` for system
features, `modules/users/features/` for Home Manager features,
`modules/users/<user>/` for user profiles. This mirrors the dendritic pattern
so the eventual `flake-parts` + `import-tree` move is mostly mechanical.

Rationale: file-path independence and self-registering features later.
Precedent: [mightyiam/dendritic](https://github.com/mightyiam/dendritic),
[Misterio77/nix-starter-configs](https://github.com/Misterio77/nix-starter-configs)
("Got some configurations you want to create an abstraction of? Modules are the
answer.").

### D2 — Host-specific data via typed options, not `extraSpecialArgs` (settled)
Monitor and workspace-rule data lives in the host and is passed through
`home-manager.users.<user>.my.*` options. `specialArgs`/`extraSpecialArgs` is
reserved for genuinely external values (`inputs`).

Rationale: `specialArgs` is an untyped, non-merging bag; the nixpkgs module docs
warn it limits interoperability. Options give merging, defaults, typing, docs.
Precedent: [nixpkgs module docs](https://github.com/NixOS/nixpkgs/blob/master/doc/module-system/module-system.chapter.md).

---

## Desktop / program abstraction

### D3 — Roles as custom options: `my.desktop.programs` and `my.desktop.services` (settled)
Roles are declared as `nullOr str` options under a compositor-agnostic
namespace. `programs.*` are exec-on-demand apps; `services.*` are session
daemons started at login.

- `my.desktop.programs`: `terminal`, `fileExplorer`, `browser`, `launcher`,
  `clipboardPicker`, `lock`.
- `my.desktop.services`: `statusBar`, `idle`, `wallpaper`, `clipboardWatcher`.
- `services.lockDaemon` (persistent lock daemon) comes later with the deferred
  quickshell lock flow.

Rationale: Hyprland itself ships this idiom (`local terminal/fileManager/menu`),
and the module system's designed purpose is options-as-interfaces. The
apps/services split keeps a consumer from ever `exec`-ing a bar.
Precedent: Hyprland's own [example/hyprland.lua](https://raw.githubusercontent.com/hyprwm/Hyprland/main/example/hyprland.lua);
[egara/nixos-config](https://github.com/egara/nixos-config) declares
`programs.sicos.hyprland.shell = enum [ "waybar" "dank-material-shell" "sicos-bar" ]`.

### D4 — Roles are explicit per-role typed options, camelCase (settled)
Each role is its own `nullOr str` option (`programs.terminal`, `services.idle`),
not an `attrsOf str` bag. Names are camelCase now that they're Nix.

Rationale: typos and unknown roles error at evaluation; options are
documentable. Precedent: dendritic's "Not declaring options" anti-pattern.

### D5 — Providers set defaults; user/host overrides (settled)
The feature that provides a capability sets its role with `lib.mkDefault`
(e.g. the ghostty feature sets `programs.terminal = "ghostty"`); the user or
host overrides by setting the option normally. Enables "install a bundle,
swap one role" without forking the feature.

### D6 — Unset roles are skipped; terminal-only fallback (settled)
An unset role emits no bind/autostart line. The bare terminal bind uses
`xdg-terminal-exec` (a proposed freedesktop spec) regardless, so it works even
if `programs.terminal` is unset. No fallback for other roles.

Precedent: [xdg-terminal-exec](https://manpages.debian.org/testing/xdg-terminal-exec/xdg-terminal-exec.1.en.html).

### D7 — `terminal` role used for composed commands (settled)
The bare "open terminal" bind is `xdg-terminal-exec`; `programs.terminal` is
still used where a terminal is composed (e.g. `fileExplorer = "<terminal> -e yazi"`).

### D8 — Autostart: services auto-start + ordered arbitrary list (settled)
`my.desktop.services.*` are started automatically. Arbitrary startup commands
(env, polkit agent, clipboard watchers, gsettings, theme) go in an ordered
`my.hyprland.autostart` (`listOf str`). Emission order: explicit list first,
then services last. Features append with `lib.mkAfter`. Services start via
`hl.on("hyprland.start")` + `exec_cmd` — one uniform mechanism, not a mix of
Hyprland autostart and systemd user units.

### D9 — Features contribute binds/autostart directly (settled)
There is no `extraBinds`/`extraAutostart` interface; a feature (e.g. quickshell)
is just another module and contributes to
`wayland.windowManager.hyprland.settings.bind` and `my.hyprland.autostart`
directly. Revisit only if a second consumer needs it.

---

## Hyprland configuration

### D10 — HM generates the Lua config; split across Nix modules (settled)
`wayland.windowManager.hyprland` with `configType = "lua"`. The `settings`
option merges across modules (verified: `oneOf` → `either` → `attrsOf`
recursive merge, `listOf` concatenates), so each concern is its own file:
`variables`, `settings` (config tree), `binds/`, `env`, `animations`,
`windowrules`, `monitors`, `workspacerules`.

### D11 — `package = null; portalPackage = null` (settled)
NixOS `programs.hyprland` provides the compositor and portals; the HM module
only generates config, avoiding a duplicate package/portal.

### D12 — Host-specific monitors & workspace rules as options (settled)
`my.hyprland.monitors` and `my.hyprland.workspaceRules` (`listOf (attrsOf
anything)`), set by each host. Loose typing for now; tighten to submodules if
the shape settles.

### D13 — Binds split into `binds/{apps,windows,workspaces,media}` (settled)
The binds module is the largest; split by concern. Tool-specific binds live in
the feature that owns the tool, not in the hyprland feature:
- clipboard bind → clipboard feature
- screenshots → screenshots feature
- scratch terminal → ghostty/editor feature
- pill keyboard → quickshell feature

### D14 — Quickshell-specific binds live in the quickshell feature (settled)
`pillKeyboard` is not a role; it is quickshell-Pill-specific and belongs to the
quickshell feature.

---

## Session / display manager

### D15 — greetd + tuigreet instead of SDDM (settled)
SDDM's Wayland keyboard backend is deliberately non-functional
(`WaylandKeyboardBackend::init` sets `enabled = false`), so its layout selector
is a cosmetic `ZZ` dummy. greetd + tuigreet is a Wayland-native TUI login with
no fake selector. ([SDDM source](https://github.com/sddm/sddm/blob/develop/src/greeter/waylandkeyboardbackend.cpp))

### D16 — No X11 / no X server (settled)
Hyprland on Wayland, SDDM replaced by greetd; `console.useXkbConfig = true` so
the TTY/greeter keymap matches `services.xserver.xkb.layout`. XWayland stays on
for X app compatibility.

---

## Config management & artifacts

### D17 — Nix-generated artifact bundles deferred (open)
An earlier attempt bundled generated configs for stow/one-off use. Dropped: not
every feature is a program that should be exported. Future: features
*self-register* what is exportable. See [ROADMAP.md](./ROADMAP.md).

### D18 — colourme is a palette→template renderer; Nix integration deferred (open)
colourme renders template files from base16/24 palettes and copies them into
config dirs (with an optional post hook), so the whole system theme can be
switched with one command. It does *not* read wallpapers (it can set them). Nix
integration is deferred until we understand the fit: Nix-managed config files
are read-only store symlinks, so colourme must target a runtime-writable
location that the Nix-generated configs *include* (e.g. a `require`d theme
module). For now `activeBorderColor` is inlined in `settings.nix`.

### D19 — Quickshell configs via HM `programs.quickshell.configs`, symlinked first (settled)
Adopt model B: named configs (`Pill`, `lockdaemon`) with `activeConfig = "Pill"`.
The quickshell config is copied into this repo under `configs/quickshell/`; the
dotfiles copy is left untouched so the live machine keeps working. Each config
path starts as an out-of-store symlink (editable QML) and can be converted to
generated Nix over time.

### D20 — Scripts as `writeShellApplication`, owned by the quickshell feature (settled)
`open-pill-surface.sh` and `lock.sh` become apps with `runtimeInputs`; the
`pillKeyboard` bind lives in the quickshell feature.

---

## Secrets

### D21 — Secrets never in git or the Nix store (settled)
Untracked files symlinked in; not read by Nix. Later: Bitwarden SSH agent /
Secrets Manager. See [ROADMAP.md](./ROADMAP.md).

---

## Hypr ecosystem defaults

### D22 — Hypr ecosystem defaults make hyprland a usable DE (settled)
Enabling the hyprland feature pulls a `hyprland-ecosystem` feature which installs
and `mkDefault`s: `launcher` → `hyprlauncher`, `lock` → `hyprlock`, `idle` →
`hypridle`, `wallpaper` → `hyprpaper`, `statusBar` → `waybar`. It also ships
minimal configs (`hypridle.conf`, `hyprpaper.conf`, `hyprlock.conf`, waybar
`config`/`style.css`) so they run out of the box. A host/user can override or
drop any of them. Rationale: "hyprland alone should be a usable desktop."

---

## Session autologin & lock

### D23 — Autologin + lock-as-greeter deferred (open)
Keep greetd + tuigreet as a normal greeter for now. The "autologin, then the
quickshell lock screen is the login" flow is deferred. It is a display-manager
concern (system-level), not a separate `session.nix` connector module: if
revisited, the option lives with the DM feature and asserts against the
embedded HM config (a NixOS module can read
`config.home-manager.users.<user>.my.desktop.services.lockDaemon`).

### D24 — Lock: `programs.lock` now, `lockDaemon` deferred (settled/open)
`programs.lock = "hyprlock"` (lock now) is provided by the baseline feature and
bound to `$mod+L`. A persistent lock daemon (`services.lockDaemon`, e.g.
quickshell's) lands with the deferred lock/autologin flow.

---

## Static configs & browsers

### D25 — Static configs stay in their native language under `configs/` (settled)
Rule of thumb: if a config is unlikely to vary between hosts, keep it in its
original language in `configs/<tool>/` and symlink it in out-of-store (stays
editable live); if it is likely to differ per host, generate it with Nix. Thin
configs can still be inlined as `.text` (ghostty, hypr ecosystem); full native
configs are symlinked (`configs/quickshell/`, `configs/tmux/tmux.conf`).
Open sub-point: sharing constants (colours/theme) across a native config and
Nix-generated configs. Likely shape: Nix renders a small theme/constants file
into a writable location that the native config `source-file`s.

### D26 — Zen browser via community flake + Home Manager module (settled)
Zen is not in nixpkgs (verified against the pinned `26.05` and unstable). Use
`0xc000022070/zen-browser-flake` (`homeModules.beta`), set
`programs.zen-browser.enable` + `setAsDefaultBrowser`, and set
`my.desktop.programs.browser = "zen-beta"`. Revisit for the official nixpkgs
package if it lands (see [NixOS/nixpkgs#496647](https://github.com/NixOS/nixpkgs/pull/496647)).

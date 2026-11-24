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

### D32 — hyprbars buttons need the plugin Lua API, loaded at parse time (settled)
With Home Manager's Lua config type (`configType = "lua"`), hyprbars 0.55
registers *only* the Lua API `hl.plugin.hyprbars.add_button`; the
`hyprbars-button` config keyword is registered only for `CONFIG_LEGACY`. The
previous approach — `hyprctl keyword 'plugin:hyprbars:hyprbars-button' …` at
`hyprland.start` — was therefore a silent no-op: the bars rendered (bar config
values are still registered) but no buttons ever appeared. HM loads plugin
*packages* after the config is parsed (an async `hyprctl plugin load` in the
`hyprland.start` hook), so the Lua function does not exist at config scope.
Fix: load the plugin at parse time with `hl.plugin.load` (Hyprland then loads it
and reloads the config; this is the API upstream HM later adopted for its plugin
option) and register the buttons behind an `if hl.plugin.hyprbars ~= nil` guard,
so the reload that follows the load actually adds them.

Button *actions* carry a second Lua-era gotcha: under `CONFIG_LUA`,
`hyprctl dispatch` is a shorthand for `hl.dispatch(...)` (HyprCtl.cpp), so
legacy dispatcher names (`killactive`, `togglefloating`, `fullscreen`) evaluate
as invalid Lua and the click silently does nothing. Actions must use the Lua
dispatch form, e.g. `hyprctl dispatch 'hl.dsp.window.close()'` and
`'hl.dsp.window.float({ action = "toggle" })'`. Upstream:
hyprland-plugins#676. Colours are not hardcoded — the buttons read
`failure`/`warning`/`success` from `require("theme.colourme")` (the `warning`
key was added to the hypr template), so they retheme with the scheme. The
buttons fall back to the stock macOS colours when a key is absent. Seed-owned
theme files are refreshed on rebuild, but a colourme-owned theme written before
a template key was added keeps its own content; it must not break the config.
Run `colourme <scheme>` to regenerate that file with `warning`.

The same trap applies to anything that shells out to a dispatcher, including
`swaync`'s power menu: "logout" is `hyprctl dispatch 'hl.dsp.exit()'`, not
`hyprctl dispatch exit`.

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

### D18 — colourme is a palette→template renderer; Nix integration deferred (superseded by D27)
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

### D22 — Hypr ecosystem defaults make hyprland a usable DE (superseded by D29)
Enabling the hyprland feature pulled a `hyprland-ecosystem` feature which
installed and `mkDefault`s a launcher/lock/idle/wallpaper/status-bar. Rationale:
"hyprland alone should be a usable desktop." Superseded by D29 — the ecosystem
became a first-class desktop environment (LitheDE) rather than an implicit
default, and the OSD/notification/dock surfaces grew.

### D29 — Two peer desktop environments on a shared compositor base (settled)
The `hyprland` feature is compositor-only (DE-agnostic). Desktop environments
are peers under `modules/users/desktops/<slug>/`, selected by the single option
`my.desktops.environment` (enum, default `"lithe"`); a structural guarantee
makes "at most one" automatic, so no assert is needed. LitheDE (`lithe`) is the
default, mouse-first, general-audience DE; LiquoRice (`liquorice`) is the
personal Quickshell DE. Each DE's config is gated on its own slug, so swapping
is one option — no forks, no `mkForce`, no default-plus-overrides hierarchy.

The visual half of the compositor config (`general`/`decoration`/`group`/
animations) lives per-DE; the non-visual half (input, misc, cursor, master,
binds, monitors, rules, autostart) stays shared. Deliberate duplication is
accepted so the two DEs can diverge. Full design: [LITHEDE.md](./LITHEDE.md).

### D30 — LitheDE is mouse-first (settled)
LitheDE targets relatively non-technical users: core actions must be reachable
without keybinds. Concretely: waybar top bar with a launcher button, a taskbar
(`wlr/taskbar`, click to focus / middle-click to close) and workspaces centred;
hyprbars window title bars with close/float/fullscreen buttons; a swaync
control center (power, Wi-Fi toggle) as the "mini settings menu"; hyprlauncher
as the single launcher + clipboard picker (dmenu mode; no wofi); swayosd for
the transient volume/brightness OSD. All themed from the shared colourme
palette. This grows D3's role set with `services.osd`.


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

---

## Theming (colourme)

### D27 — Seam model: Nix owns structure, colourme owns themed bytes (settled)
The Nix store is immutable and colourme writes in place, so Nix must never own
a themed value. Instead Nix generates *structure* and points each themed value
at a **runtime-writable** file that colourme renders; live reload is driven by
colourme's own `post_hook`s. Three seams: Hyprland (`require("theme.colourme")`
in the generated lua, via `lib.generators.mkLuaInline`), Ghostty (`theme = Luka`
pointing at a runtime theme file), Quickshell (`FileView` watcher on a runtime
JSON, replacing the old overwrite-`Colours.qml` approach so generated colour
data stays out of git). Waybar/tmux/starship are out of scope; tmux/starship
inherit Ghostty's palette.

The toolkit seams added for LitheDE (D29/D30/D31) extend the same model:
**GTK3** (`@import "colourme-gtk.css"` from a Nix-owned `gtk-3.0/gtk.css`;
colourme writes `@define-color theme_*`), **GTK4/libadwaita** (same trick in
`gtk-4.0/gtk.css` + `gtk-dark.css`, overriding libadwaita's named colours), and
**waybar** (`@import "colourme-waybar.css"`). GTK/waybar reload on app restart;
the colour names churn across versions (re-check on bumps). Qt palette is
`qt6ct` (no colourme seam yet).

colourme's inputs (`config.toml`, `templates/`, `schemes/`) live in
`configs/colourme/` and are symlinked out-of-store to `~/.config/colourme` so
they stay live-editable. Defaults (so apps don't depend on colourme) are
rendered at build time from the same templates by a packaged colourme
(`--no-hooks --dest-root`) and seeded at activation. Each seeded file has a
stamp of the bytes last written: while the live file matches its stamp it is
still seed-owned and is refreshed on rebuild (so template and `defaultScheme`
changes propagate); once colourme writes a different theme it no longer
matches and is left alone. The default scheme is a `my.theme.defaultScheme`
option. colourme is a build input only, never installed. This requires colourme interface changes (`--config`,
`--schemes-dir`, `--no-hooks`, `--dest-root`, relative-path resolution,
parent-dir creation) and a colourme flake.

Full plan: [THEME-PIPELINE.md](./THEME-PIPELINE.md). Required colourme changes
are specified in that repo's `INTERFACE_CHANGES.md`.

### D31 — Fonts vendored in-repo; Adwaita shapes everywhere (settled)
Fonts are vendored under `fonts/` in this repo (self-contained; `~/dotfiles`
may be deprecated) and symlinked out-of-store into `~/.local/share/fonts`, so
the ~134 MB never enters the Nix store. Set: SF Pro Text/Display, SF Mono,
SymbolsNerdFont, Roboto, Inter, Ubuntu. SF is the *LitheDE UI face only*, not a
global fontconfig preference. The blanket
`~/.local/share/fonts -> ~/dotfiles/fonts` stow symlink is dropped.

Toolkit cohesion favours **identical widget shapes over a literal macOS look**:
GTK3 uses `adw-gtk3`, GTK4/libadwaita uses Adwaita (+ colourme overrides),
Qt uses `adwaita-qt6`. Icons/cursors are WhiteSur (art, independent of shape).


---

## Removable media

### D28 — Removable-media automount as a role-backed feature (settled)
`udiskie` provides the session role `my.desktop.services.removableMedia` (D3/D5)
and starts via Hyprland autostart like every other service (D8). Its config is
generated from Nix so the browse/terminal actions follow
`my.desktop.programs.{fileExplorer,terminal}` (D7): setting those roles anywhere
carries over without editing the automount feature. The system side stays in the
`desktop` host feature: `services.udisks2.enable` (which also enables polkit)
plus `boot.supportedFilesystems = [ "vfat" "exfat" "ntfs" ]` for the common
removable formats. SD cards behind a USB reader/hub need nothing extra — they
present as ordinary USB mass storage.


---

## Desktop shell

### D33 — Fused status+dock bar; one window-switching surface (settled)
LitheDE's bar is a single top strip that does both jobs macOS splits between the
menu bar and the Dock: launcher + running windows on the left, status and power
on the right. The earlier layout showed `wlr/taskbar` *and*
`hyprland/workspaces` side by side, which duplicated one idea in two mental
models — app-centric (Windows/macOS) and space-centric (tiling) — and read as
noise.

Settled behaviour:

- The launcher is a magnifier glyph, not an "Apps" label: it opens a search UI.
- The dock lists running windows only (`wlr/taskbar`). Left click focuses,
  middle closes, right toggles maximize. Waybar fires exactly one fixed action
  per button and cannot chain commands, and Hyprland's foreign-toplevel
  maximize request only sets the fullscreen mode (it does not move focus), so
  "focus *and* maximize" is not expressible as a single click.
- The primary mouse affordance for maximize is the green traffic light, which
  toggles `FSMODE_MAXIMIZED` (fills the workspace but keeps gaps and the bar)
  rather than true fullscreen — macOS green semantics.
- Workspaces are status only: small, tightly packed dots for workspaces 1–5,
  lit only while occupied, never numbers. Fixed slots avoid the row shifting
  when a new workspace is created. Clicking a slot switches to it.
- The focused dock entry gets a straight underline with rounded caps rather
  than an accent-tinted background.
- Fading the other dock entries while the focused window is maximized was
  tried and **dropped**: GTK CSS cannot express it (no `:has()`), so it needed
  a Hyprland-event watcher rewriting a runtime stylesheet, and the plumbing
  cost outweighed the benefit. Deferred, not rejected on design grounds.

Rejected: workspaces only (a stranger cannot switch windows with the mouse);
taskbar only (drops the space indicator keyboard users rely on); a scripted
global float mode (Hyprland has no float-all; a Lua loop over `hl.get_windows`
plus map-time rules leaks on every new window and produces exactly the manual
window clutter tiling exists to avoid).

Waybar 0.15 has no app grouping and no pinned non-running apps, so a real Dock
(pinned
favourites) would need a custom component, not another waybar module.

---

## LiquoRice

### D34 — LiquoRice runs the QML out-of-store, with helper scripts at fixed paths (settled)
The Quickshell config is symlinked whole: `~/.config/quickshell` →
`configs/quickshell` (`mkOutOfStoreSymlink`, D25), so the pill, the lock daemon,
and the shaders stay editable on the live machine. `Ricelin/` stays a gitlink
(upstream provenance only) and is deliberately **not** synced — nothing in the
live QML imports it.

The QML hard-codes three helper paths:

- `~/.config/hypr/scripts/open-pill-surface.sh` — resolves the focused
  monitor and calls `quickshell ipc call pill <surface> <mon>`.
- `~/.config/hypr/scripts/lock.sh` — starts/wakes the lock daemon, pokes
  `$XDG_RUNTIME_DIR/lock-trigger`, then calls `ipc call lock lock`.
- `~/.config/hypr/scripts/cliphist-thumbs.sh` (+ `magick-policy/`) — decodes
  clipboard images behind an ImageMagick policy cage.

Rather than patching the QML, `configs/hypr/scripts` is symlinked to
`~/.config/hypr/scripts` and the copies are adapted for NixOS (`qs` →
`quickshell`). All other external commands (`hyprctl`, `cliphist`, `ddcutil`,
`nmcli`, `brightnessctl`, `notify-send`, `slurp`, …) resolve from
`home.packages` on the session `PATH`, matching the dotfiles' assumptions.

Ownership: the pill is the notification server (`Quickshell.Services.
Notifications`) and the OSD, so `services.notification` and `services.osd` stay
`null`; `hypridle` and `hyprpaper` remain the idle/wallpaper providers with
LiquoRice-specific configs. LitheDE's toolkit theming (GTK/Qt/icons) is
per-DE and does not apply yet — LiquoRice starts unthemed at the toolkit layer.

---

## Terminal multiplexer

### D35 — One multiplexer auto-attaches via a role, tmux outranks herdr (settled)
Ghostty runs whatever `my.desktop.programs.multiplexer` points at instead of a
login shell. Providers set the option at different priorities: the tmux feature
sets it normally, herdr sets it with `mkDefault`. Importing both therefore
attaches tmux; importing only herdr attaches herdr. Dropping the tmux feature
from the user profile is what makes herdr the active multiplexer today — re-add
the import to flip back.

Herdr is packaged from its pinned release binary (`packages/herdr`) rather than
the upstream flake: that flake builds from source against nixos-unstable with a
pinned Rust/zig toolchain, which is a large rebuild for a static binary. The
hash/version pair is documented in the package and taken from
`https://herdr.dev/latest.json`; bump both together.

---

## Work environment (MSI)

### D36 — MSI tooling is a separate overlay flake consumed by this config (settled)
The MSI development environment lives in a separate flake,
`~/code/msi-nix` (`msi-nix`), pinned here as a `git+file:` input. It owns the
Ruby 3.0.7 toolchain, the process-compose stack, the `msi` CLI and the
Home Manager/NixOS modules; `nixos-config` only imports those modules. Keeping
it separate means the work environment can be shared with another machine (or
published privately) without dragging personal system configuration along, and
per-repo flakes can be added later without restructuring this flake. The
overlay's decisions and roadmap are recorded in `msi-nix/docs/`.

### D37 — Work trees live under `~/code`; there is no `~/Code` (settled)
`~/code/msi/<repo>` is the work root (`MSI_CODE_ROOT`) and `~/code/msi-nix` is
the overlay. `~/Code` was only a convenience assumed by documentation; local
tooling reads `MSI_CODE_ROOT`, and only the server-side `configure` roles
hardcode a `Code` directory for the deployer user. The Home Manager symlink was
removed. Other personal projects still live under `~/projects/code` for now;
consolidating them under `~/code` is a separate cleanup.

### D38 — The NixOS test VM is a disposable agent target (settled)
The VM is driven over SSH from the workstation: a dedicated key
(`~/.ssh/id_ed25519_vm`), a SLIRP host forward
(`hostfwd_add tcp:127.0.0.1:2222-:22`; libvirt's declarative `<portForward>`
requires the `passt` backend, which is not installed), `wheelNeedsPassword =
false` and `trusted-users = @wheel` so closures can be copied from the
workstation. These concessions are for the disposable VM only and must not be
copied to a real host.

### D39 — LiquoRice uses the WhiteSur cursor; hypridle is off (settled)
The compositor's built-in cursor was the blue default. LiquoRice now sets
`home.pointerCursor` and `XCURSOR_THEME=WhiteSur-cursors` (package installed),
and the running session applies it with `hyprctl setcursor`. Idle/lock is
disabled for now by not setting `services.idle`; hypridle is still installed and
its config remains so re-enabling is one line (`idle = lib.mkDefault
"hypridle";`).

---

## Workstation (Arch → NixOS)

### D40 — `luka-workstation` starts as a dual-boot trial (settled)
The workstation is a Ryzen 9800X3D + RX 9070 XT on a Gigabyte B850M. It gets its
own host entry and a **separate 1 GiB ESP + systemd-boot** while Arch keeps its
512 MiB ESP/rEFInd as the fallback. Windows lives on its own ESP on the second
NVMe; systemd-boot reaches it through the EDK2 shell handle (`map -r`; `FS0` as
of 2026-11-24), with the firmware menu as the fallback. After a full NixOS
workday, Arch is wiped and NixOS takes the whole disk. See
[WORKSTATION.md](./WORKSTATION.md).

### D41 — LUKS2 + btrfs subvolumes; Secure Boot is deferred (settled)
The NixOS partition is LUKS2 (passphrase) with btrfs `@`, `@home`, `@nix`
subvolumes and zstd; the existing 4 GiB swap partition is reused. Secure Boot
is intentionally postponed until after Arch is removed, then lanzaboote with
custom keys.

### D42 — Creative apps are native; Affinity is a flake (settled)
Slack, Spotify, Discord, VLC, OBS and DaVinci are native nixpkgs packages; no
Flatpak for the must-have set. Affinity v3 comes from
`mrshmllow/affinity-nix` (Wine prefix built in Nix, unfree, vendor installer,
binary cache at `cache.forall.systems`) rather than the 2 GB AppImage. DaVinci
on RDNA4 is a known risk because nixpkgs 26.05 ships ROCm 7.2.3; Arch/Windows
remain the fallback until that stack is proven. Discord is the official native
client first; Vesktop is the fallback if Wayland screen sharing is poor.

### D43 — OpenRGB/CoolerControl are seeded, not locked (settled)
OpenRGB runs its SDK server with the `true-white` profile; the GUI can still
connect, and `colourme`'s `openrgb -c ...` hook targets the server. Profiles and
the CoolerControl 5.x `config.toml`/`overrides.toml` are committed under the
host directory and seeded once into `/var/lib/...`; the daemon owns them after
that. CoolerControl comes from `Daaboulex/coolercontrol-nix` (5.1.2; nixpkgs is
4.3.0). RAM detection on the ENE controllers is inconsistent; it is **not**
retried from Nix for now and will be investigated after the switch.

### D44 — Google Drive is a tuned rclone mount; backups are restic (settled)
`rclone mount` with `--vfs-cache-mode full` (30 GiB cache by default, tunable via
`my.gdrive`) replaces the old cache-less mount that made Drive slow. `gdrive-pin`
copies selected paths to `~/GoogleDrive-offline` for guaranteed offline access.
The OAuth config stays in `~/.config/rclone/rclone.conf`. Backups use restic to
`rclone:gdrive:backups/luka-workstation`, with the password outside git; browser
profiles are mostly skipped because Mozilla sync covers them.

### D45 — The WD disk moved from MBR to GPT during the install (settled)
Arch shipped on an `msdos` label with three primaries. MBR allows four primary
partitions and the dual-boot needs five (Arch ESP, swap, Arch root, NixOS ESP,
NixOS root), so the disk was converted with `sgdisk -g` after the btrfs shrink
freed space at the end. Two things made it safe: `parted` refuses to shrink in
`-s` mode (it prints the data-loss warning and answers no), so the shrink is
done interactively; and the partition end is computed from
`btrfs inspect-internal dump-super` in sectors, rounded up, rather than as
`old_end - 120GiB`, which on this disk was 688 sectors short and would have
truncated the filesystem. GPT regeneration changed every partition GUID;
Arch's `fstab` and kernel cmdline use filesystem `UUID=`, so it still boots, and
its rEFInd NVRAM entry was recreated with `efibootmgr`. The disk is now fully
allocated, with no free space after p5.

### D46 — `@ssh` is folded into `@home` on NixOS (settled)
Arch keeps `~/.ssh` in its own subvolume and NixOS deliberately does not. No
snapshot or scrub service is configured on NixOS, so a separate subvolume buys
nothing today and costs a mount entry and a restore footgun. The keys were
copied into `@home/luka/.ssh` (0700, uid 1000). If snapper is ever introduced
for `/home`, split `@ssh` out **before the first snapshot** — a snapshot taken
with the keys inside keeps them forever, including after rotation.

### D47 — The IT8696 needs the out-of-tree `it87` module (settled)
Mainline `it87` does not recognise the IT8696E, so `boot.kernelModules = [
"it87" ]` alone fails with "No such device" even with
`acpi_enforce_resources=lax` (which Gigabyte firmware also requires, and which
Arch's cmdline already had). Nixpkgs ships Frank Crawford's driver as
`config.boot.kernelPackages.it87`; it goes in `boot.extraModulePackages`. Both
trees carry `hwmon/it87.ko`, so a rebuild may need
`system.modulesTree = lib.mkForce [ … ignoreCollisions = true … ]` with the
extra package listed first. CoolerControl depends on this for any fan control.

### D48 — `gh` owns `~/.config/gh/config.yml` (settled)
home-manager's `programs.gh` always materialises `config.yml` as a read-only
store symlink, which makes `gh auth login` fail with `read-only file system`.
The module's `xdg.configFile."gh/config.yml".enable = false` override is set so
`gh` can write its own preferences. `hosts.yml` (the token) stays unmanaged
because `programs.gh.hosts` is left empty. Authentication is stored as a 0600
file inside the LUKS-encrypted home (`--insecure-storage` if a keyring blocks
the login).

### D49 — Arch is removed by a clean re-layout, not an in-place grow (settled)
NixOS occupies the last partition, and its LUKS2 header sits at that
partition's front, so deleting Arch frees space that cannot extend the NixOS
root. The plan is therefore: verified backup, rescue the restic password and
rclone config off-disk, wipe the WD disk, create a 1 GiB ESP plus one LUKS2
partition filling the disk, reinstall from the flake, and restore `/home`. The
in-place alternative (`btrfs device add` into the freed space with a second LUKS
device) is documented as a fallback only: two unlock prompts, a root filesystem
split across two partitions on one disk, and no advantage over a reinstall.
Gated on a full NixOS workday. See
[WORKSTATION-ARCH-REMOVAL.md](./WORKSTATION-ARCH-REMOVAL.md).


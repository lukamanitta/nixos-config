# LitheDE — default desktop design

Status: **implemented (v1) for LitheDE**; LiquoRice and some polish items are
backlog. Names are provisional (they will change) but the slug forms `lithe` /
`liquorice` are used throughout.

Related: [DECISIONS.md](./DECISIONS.md) (D22 is reshaped by this doc),
[THEME-PIPELINE.md](./THEME-PIPELINE.md) (extended by the toolkit seams below),
[ROADMAP.md](./ROADMAP.md).

## Context

The repo currently ships one implicit desktop: the `hyprland` feature plus a
`hyprland-ecosystem` feature that `mkDefault`s a launcher/lock/idle/wallpaper/
status-bar and ships minimal inline configs (D22). Theming is a colourme
pipeline with three seams (Hyprland, Ghostty, Quickshell) and a build-time
default render seeded at activation (D27).

We are splitting the desktop into **two peer desktop environments**:

- **LitheDE** — the default, out-of-the-box, general-audience DE. Usable by
  relatively non-technical people: basic functionality is reachable by mouse,
  not hidden behind keybinds.
- **LiquoRice** — the personal, in-progress Quickshell environment. Covers all
  desktop roles itself and is developed independently.

They are *not* a default-plus-overrides hierarchy. They are siblings over a
shared base; a host/user picks exactly one. Anything genuinely shared is shared
by both; everything else belongs to one DE.

## Goals

- A default desktop that is **usable on first boot** with no config edits.
- **Mouse-first**: launch apps, switch/focus/close windows, control the system,
  change the theme — all without keybinds.
- **Cohesive**: shared padding, radii, fonts, transparency, and colours across
  every surface (bar, launcher, notifications, OSD, control center, GTK/Qt apps).
- **Runtime-recolourable** where feasible: `colourme <scheme>` retheme the
  running desktop.
- **Peer DEs**: adding/dropping a DE is one boolean; no fork/`mkForce` wars.

## Non-goals

- Distribution/redistribution (personal-first; see Fonts).
- A full Settings application. The "mini settings menu" is a control center,
  not a GNOME/KDE control panel.
- Pixel-identical Qt↔GTK. Target is family-consistent (same colours and widget
  shapes), not identical.
- Making LiquoRice here — it stays its own track.

## Architecture

### Shared base vs per-DE

**Shared (survives a DE swap):**

- The Hyprland compositor config: `variables`, `input`, `misc`, `cursor`,
  `master`, `env`, `monitors`, `workspacerules`, `windowrules`, `autostart`,
  base `binds`, and the colourme-wired border colour.
- The role interface `my.desktop.{programs,services}`.
- The **colourme** pipeline (palette engine, default scheme, runtime files).
- **Fonts**.
- Compositor-agnostic apps: Ghostty, shell/CLI, portals/polkit, removable-media
  (`udiskie`), browser (Zen).
- Universal binds: close, focus, workspace switching, mouse drag/resize.

**Per-DE (one DE owns these end-to-end):**

- Compositor **look** (`general` gaps/border, `decoration`, `group`) and
  **animations** (curves + animation list + gesture). These are physically
  removed from the shared feature — duplication between DEs is accepted so the
  two can diverge freely.
- Bar/panel, notifications, launcher, lock + idle + wallpaper providers,
  window decorations, OSD.
- Its **design tokens**.
- DE-specific binds (launcher key, panel keys) and app configs.

### Repo layout

```
modules/
  users/
    desktops/
      default.nix            # declares my.desktops.<slug> options + the assert
      lithe/                 # the default DE (absorbs hyprland-ecosystem.nix)
      liquorice/             # personal Quickshell DE (developed separately)
    features/                # shared features (hyprland core, colourme,
                             # fonts, ghostty, desktop roles, ...)
    <user>/
```

Config files (non-Nix) stay under `configs/<tool>/`, symlinked out-of-store per
D25, unless generated.

### Selection & overridability

- `my.desktops.environment = "<slug>"` selects the active DE (a `nullOr (enum
  [...])`, default `"lithe"`). Because it is a *single* option, "exactly one DE"
  is structural — no assertion needed (changed from the initial
  `my.desktops.<slug>.enable` + assert idea, which couldn't make "enabling a DE
  wins the default" true with independent booleans).
- Each DE's config is gated on `my.desktops.environment == "<slug>"`.
- Selecting a peer (e.g. LiquoRice) is one option flip; disabling all (`null`)
  runs the bare shared compositor with no shell.
- Per-DE toggles live under `my.desktops.<slug>.*` (e.g.
  `my.desktops.lithe.windowControls`).

## Theming pipeline (colourme seams)

Model is D27 unchanged: **Nix owns structure and geometry; colourme owns
palette bytes written to runtime-writable files.** Extended with toolkit seams:

| Surface | Nix owns (structure) | colourme writes (runtime) | Reload |
|---|---|---|---|
| Hyprland | generated lua `require("theme.colourme")` | `~/.config/hypr/theme/colourme.lua` | `hyprctl reload` |
| Ghostty | `theme = Luka` | `~/.config/ghostty/themes/Luka` | `pkill -USR2 ghostty` |
| Quickshell | `FileView` watcher | `~/.local/state/colourme/colours.json` | watch (instant) |
| **GTK3** | `gtk-3.0/gtk.css` = `@import "colourme-gtk.css";` | `gtk-3.0/colourme-gtk.css` (`@define-color theme_*`) | app restart |
| **GTK4** | `gtk-4.0/gtk.css` (+ `gtk-dark.css`) `@import` | `gtk-4.0/colourme-gtk.css` (`@define-color window_*`, `accent_*`) | app restart |
| **Qt** | `qt6ct.conf` shell / env | rendered palette | app restart |

GTK colour overrides are the supported way to recolour **libadwaita** apps
(named `@define-color`s). Caveat: the libadwaita colour *names* churn across
versions — verify against the pinned GTK/libadwaita.

## Design tokens (LitheDE v1)

Living in one Nix module under `modules/users/desktops/lithe/`, consumed by
generated configs and colourme templates.

| Token | Value |
|---|---|
| Radii — window / panel | `10` |
| Radii — popover / menu | `12` |
| Radii — inner control | `panel_radius − padding` |
| Spacing scale | `4 / 8 / 12 / 16` (gaps_in 4, gaps_out 8) |
| Font sizes | UI `13`, small `11`, large `15`, title `17` |
| Opacity | bar `0.8`, menus/popovers `0.9`, osd/notifications `0.85` |
| Window opacity | active `1.0`, inactive `0.96` |
| Border | active `2px` colourme accent; inactive `1px` subtle |
| Shadow | range `24`, offset `0 4`, render_power `3`, ~`45%` black |
| Blur | size `6`, passes `2`, vibrancy `0.2` |

Values are a starting point and will be tweaked.

## LitheDE component stack

### Roles / providers

| Role | LitheDE provider | Notes |
|---|---|---|
| `programs.launcher` | `hyprlauncher` | also the clipboard + power picker |
| `programs.lock` | `hyprlock` | lock now |
| `programs.fileExplorer` | `thunar` | GTK3, themed |
| `programs.clipboardPicker` | `hyprlauncher --dmenu` | over `cliphist` |
| `programs.terminal` | `ghostty` | shared |
| `programs.browser` | `zen` | shared |
| `services.statusBar` | `waybar` | top bar |
| `services.notification` | `swaync` | **replaces mako**; also the control center |
| `services.idle` | `hypridle` | |
| `services.wallpaper` | `hyprpaper` | |
| `services.osd` *(new)* | `swayosd` | transient volume/brightness OSD |
| `services.clipboardWatcher` | `cliphist` + `wl-paste --watch` | shared |
| `services.removableMedia` | `udiskie` | shared |

`swaync` supplies **notifications + control center** (power, network toggles,
volume/brightness sliders, DND, night light, and — later — a theme button). A
dedicated `services.controlCenter` role is not needed.

### Panel (waybar, top bar)

- **Left:** launcher button · focused window / taskbar (`wlr/taskbar`, with
  close/minimize actions).
- **Center:** workspaces (the dock analogue).
- **Right:** tray (`nm-applet`) · clock · control-center button · power button.
- Frosted glass: CSS `rgba` surfaces over Hyprland layer blur.

### Window decorations

**`hyprbars`** (official plugin), sourced from **`pkgs.hyprlandPlugins.hyprbars`**
(built against the pinned nixpkgs Hyprland — avoids the flake/version-lock
pitfall). Adds macOS-style title bars with close/float/fullscreen buttons as
coloured circles. hyprbars 0.55 registers the `hyprbars-button` keyword only for
legacy configs; under the Lua config type buttons exist only via the plugin's
Lua API (`hl.plugin.hyprbars.add_button`). The plugin is therefore loaded at
config-parse time with `hl.plugin.load`, and the buttons are registered behind a
`hl.plugin.hyprbars ~= nil` guard (see `windowcontrols.nix`). Button actions
must use the Lua dispatch API (`hyprctl dispatch 'hl.dsp.window.close()'`):
under the Lua config type `hyprctl dispatch` is shorthand for `hl.dispatch(...)`,
so legacy dispatcher names (`killactive`, `togglefloating`, `fullscreen`) are
invalid Lua and silently do nothing. Button colours come from the active
colourme scheme (`failure` red, `warning` yellow, `success` green; the `warning`
key is added to the Hyprland colourme template), so they retheme with
`colourme <scheme>`. Gated behind
`my.desktops.lithe.windowControls`. **Risk:** plugins are version-locked;
a Hyprland bump can break the session — acceptable for personal machines, called
out for any future "reliable baseline".

### Control center & power

- **`swaync`** panel hosts quick toggles, sliders, and power actions (lock /
  logout / suspend / reboot / shutdown) via buttons-grid + custom buttons.
- **`wlogout` is dropped** — the control center owns power. (Kept in reserve if
  a fullscreen grid is ever wanted.)
- **Theme picker**: a future `swaync` panel button launching the colourme picker.

### Clipboard, screenshots

- Clipboard history: `cliphist` fed by `wl-paste --watch`; picked through
  `hyprlauncher --dmenu` (`cliphist list | hyprlauncher --dmenu | cliphist decode | wl-copy`).
- Screenshots: **`hyprshot`** (region/window/output → clipboard), optional
  annotation via **`satty`**.

### Fonts

- Curated set vendored **into this repo** under `fonts/` (self-contained;
  `~/dotfiles` may be deprecated). Set: **SF Pro Text + Display**, **SF Mono**,
  **SymbolsNerdFont**, **Roboto**, **Inter**, **Ubuntu**. (`SF-Compact` and
  `Iosevka` are out.)
- Installed by **out-of-store symlink** into `~/.local/share/fonts/<Family>`
  (no store bloat, matches the `configs/` pattern). The blanket
  `~/.local/share/fonts -> ~/dotfiles/fonts` stow symlink is dropped so Nix owns
  the set.
- **SF is the LitheDE UI face only** — not a global fontconfig preference.

### Icons & cursors

- **`whitesur-icon-theme`** (alt / redesigned macOS variant) and
  **`whitesur-cursor-theme`**. Icons/cursors are art, independent of the Adwaita
  widget-shape decision.

### Toolkit theming

- **GTK3:** base theme **`adw-gtk3`** (Adwaita shapes for GTK3 apps).
- **GTK4 / libadwaita:** Adwaita + colourme `@define-color` overrides.
- Result: **identical widget shapes across GTK3 and GTK4**, recoloured to the
  active scheme at runtime. (Accepted consequence: the shape language is
  Adwaita, not macOS-WhiteSur.)
- **Qt:** **`adwaita-qt6`** style + `qt6ct` palette (colourme-rendered) →
  Adwaita shapes in Qt too. No Kvantum/WhiteSur-Qt.

## Config placement policy (D25, applied)

- **Symlink out-of-store** (`configs/<tool>/`) — large/native configs:
  waybar (`config`, `style.css`), mako→swaync, hyprlock, hyprlauncher (once the
  format is pinned), wlogout reserve, thunar if needed.
- **Generated from Nix tokens** — waybar where geometry is tokenised, swayosd,
  GTK `@import` shells, qt6ct shell.
- **Inline `.text`** — tiny configs: hypridle, hyprpaper.
- **Hyprland** — generated, split shared/per-DE as above.

## Proposed file tree (indicative)

```
configs/
  waybar/{config,style.css}
  swaync/config.json
  hyprlock/hyprlock.conf
  hyprlauncher/…
  colourme/templates/{hypr.lua,ghostty,quickshell.json,gtk3.css,gtk4.css,qt6ct.conf}
fonts/
  SF-Pro/  SF-Mono/  SymbolsNerdFont/  Roboto/  Inter/  Ubuntu/
modules/users/desktops/lithe/
  default.nix        # enable, roles, packages, assert
  hyprland.nix       # general/decoration/group/animations (per-DE look)
  tokens.nix         # the token set above
  panel.nix          # waybar wiring
  windowcontrols.nix # hyprbars
  controlcenter.nix  # swaync
  toolkit.nix        # gtk/qt/icons/cursors
  fonts.nix
```

## Open questions / risks

- **hyprlauncher** config format is version-dependent (old `config.json` vs
  current hyprtoolkit `~/.config/hypr/hyprlauncher.conf`); confirm on the pinned
  package before templating.
- **libadwaita** `@define-color` names must be verified against pinned versions.
- **`adwaita-qt6`** availability in the pinned nixpkgs (else Qt5-only).
- **hyprbars** version-lock failure mode.
- Exact `swaync` widget composition for network *joining* (nm-applet vs a picker)
  and the theme button.
- Whether `powerMenu` / `screenshot` warrant first-class roles or stay
  feature-owned binds.

## Build sequence

1. ✅ Scaffold `modules/users/desktops/` + `my.desktops.environment`; move
   `hyprland-ecosystem.nix` into `lithe/`; select via the option (default
   LitheDE).
2. ✅ Split Hyprland config: visual keys (`general`/`decoration`/`group`) and
   `animations` moved to `lithe/hyprland.nix`; shared feature keeps the rest.
3. ✅ Vendored fonts (`fonts/` + `features/fonts.nix`) and icon/cursor themes.
4. ✅ Token module + colourme templates (`gtk3.css`, `gtk4.css`, `waybar.css`)
   and the GTK `@import` shells; wired `adw-gtk3` + `adwaita-qt6`.
5. ✅ LitheDE programs: waybar, hyprlock, hyprlauncher, swaync, swayosd,
   thunar, hyprshot, cliphist; new `services.osd` role.
6. ✅ `hyprbars` window controls: the plugin is loaded at config-parse time via
   `hl.plugin.load` (HM loads plugin packages only *after* the config is
   parsed), and buttons are added with the plugin's Lua API behind a nil-guard.
7. ✅ Docs updated (D22 superseded, D29–D31; ROADMAP desktop section).

### Remaining follow-ups

- swaync `style.css` theming; hyprlauncher `config`/theme; Qt `qt6ct` colourme
  seam; network *joining* UX (nm-applet vs a picker); real traffic-light glyphs;
  verify the WhiteSur icon/cursor theme *names* resolve (else icons fall back);
  `toString` float formatting (`0.800000` → `0.8`); unstow the old fonts symlink
  (`stow -D fonts`) on machines using the dotfiles tree.


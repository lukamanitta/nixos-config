# Theme pipeline (colourme × Home Manager)

Plan for integrating `colourme` into this flake. Status: **implemented for the
Hyprland, Ghostty, Quickshell, Zen Browser, Neovim, Spicetify and wallpaper
seams**.

Related: `DECISIONS.md` D18/D25 (superseded in part by D27), and the colourme
repo's `INTERFACE_CHANGES.md` (required changes) + `REVIEW.md` (bug list).

## Goal

Switch the whole desktop's colour scheme at runtime with `colourme <scheme>`,
while keeping Nix as the source of truth for *structure*. A fresh install must
look correct before `colourme` is ever run, without depending on it.

## The two constraints

1. **The Nix store is immutable.** Anything Nix generates is a read-only store
   symlink; `colourme` writes in place, so it can never own a Nix-managed file.
2. **`colourme` currently hardcodes its input paths and writes verbatim.** Its
   config is read from `~/.config/colourme`, so it must be told where inputs
   live and how to redirect outputs (see blockers).

## Architecture — the seam model (D27)

Nix owns structure and points each themed value at a **runtime-writable file**
that `colourme` renders. Nix never owns a themed byte. Live reload is driven by
`colourme`'s own `post_hook`s (kept in its config, not in Nix).

Seven seams, all writing **outside git**:

| App | Nix points at | `colourme` writes | Reload |
|---|---|---|---|
| Hyprland | `require("theme.colourme")` in generated lua | `~/.config/hypr/theme/colourme.lua` | `post_hook = "hyprctl -i 0 reload"` |
| Ghostty | `theme = Luka` in config | `~/.config/ghostty/themes/Luka` | `post_hook = "pkill -USR2 ghostty"` |
| Quickshell | `FileView` watcher in `Colours.qml` | `~/.local/state/colourme/colours.json` | (none — file watch is instant) |
| Zen Browser | `colourme.cfg` module registering a USER_SHEET | `~/.local/state/colourme/zen-userChrome.css` | (none — module polls the file) |
| Neovim | shims in `lua/ui/` loading runtime files | `~/.local/state/colourme/nvim/*.lua` | next Neovim start |
| Spicetify | `current_theme = Matte` / `color_scheme = colourme` | `~/.config/spicetify/Themes/Matte/color.ini` | instant while running (watcher reloads the window); next launch otherwise |
| Wallpaper | `wallpaper-restore.sh` (shared with autostart) | `~/.config/waypaper/wallpaper.ini` | `post_hook = "$HOME/.config/hypr/scripts/wallpaper-restore.sh"` |

Waybar, tmux, starship are intentionally out of scope for now. tmux/starship
inherit Ghostty's terminal palette.

## Required colourme changes (landed)

All specified in the colourme repo's `INTERFACE_CHANGES.md`. These have landed:

- **§1 create parent directories** — otherwise Nix must scaffold `.keep` files
  in `~/.config/hypr/theme/`, `~/.config/ghostty/themes/`,
  `~/.local/state/colourme/`.
- **§2 configurable input paths** (`--config`, `--schemes-dir`, XDG) — needed to
  read config/templates/schemes from a store path at build time.
- **§3 `--no-hooks`** — derivations can't run `hyprctl`/`pkill`.
- **§4 `--dest-root DIR`** — redirect `~`-based destinations under a scratch
  dir to build the default theme tree hermetically.
- **§7 relative path resolution** — `template = "templates/hypr.lua"` resolved
  against the config file, so one config works live and in the store.
- **(non-blocking but wanted)** §5 atomic writes, §6 CLI hygiene.

Separately, strategy A below needs **colourme packaged as a flake**
(`flake.nix` exposing `packages.<system>.default`, with `colour_utils` as an
input). This is now wired up as the `inputs.colourme` flake input.

## Repository layout — `configs/colourme/`

New, committed, and symlinked out-of-store to `~/.config/colourme` so templates
and schemes stay live-editable:

```
configs/colourme/
  config.toml            # single portable config (relative templates, ~ destinations)
  templates/
    hypr.lua             # emits `return { activeBorderColor = "...", ... }`
    ghostty              # ghostty theme file (background/foreground/palette 0..21)
    quickshell.json      # emits {"surfaceDefault": "...", ...}
    zen_browser.css      # Zen chrome colours (userChrome.css variables)
    nvim.lua             # sets background + vim.g.colourscheme
    nvim-base16.lua      # returns the base16 palette table
  schemes/
    _template.toml       # canonical key set
    Gruvbox.toml         # default scheme
    ...                  # a few palettes; grow as needed
```

`config.toml` (illustrative — destinations are all `~`, templates relative):

```toml
[hypr]
template = "templates/hypr.lua"
destination = "~/.config/hypr/theme/colourme.lua"
post_hook = "hyprctl -i 0 reload"

[ghostty]
template = "templates/ghostty"
destination = "~/.config/ghostty/themes/Luka"
post_hook = "pkill -USR2 ghostty"

[quickshell]
template = "templates/quickshell.json"
destination = "~/.local/state/colourme/colours.json"

[zen_browser]
template = "templates/zen_browser.css"
destination = "~/.local/state/colourme/zen-userChrome.css"

[nvim]
template = "templates/nvim.lua"
destination = "~/.local/state/colourme/nvim/set_colourscheme.lua"

[nvim-base16]
template = "templates/nvim-base16.lua"
destination = "~/.local/state/colourme/nvim/palette.lua"
```

Wiring (new `modules/users/features/colourme.nix`):

```nix
xdg.configFile."colourme".source =
  config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/nixos-config/configs/colourme";
```

## Seams

### Hyprland

HM writes `~/.config/hypr/hyprland.lua` (a real dir, so `theme/` can exist
there), and Hyprland forces `package.path` to `~/.config/hypr/?.lua` — so
`require("theme.colourme")` resolves to our runtime file. Inject the themed
values in `modules/users/features/hyprland/settings.nix` with raw Lua:

```nix
col.active_border = lib.generators.mkLuaInline
  ''require("theme.colourme").activeBorderColor'';
```

Apply to every colour value: `col.active_border` (L17), shadow `color` /
`color_inactive` (L32–33), `group.col.border_active` (L43). The `hypr.lua`
template returns a table whose keys match. Reload stays a `post_hook`.

LitheDE's `hyprbars` window-control buttons reuse this seam: they read
`failure`/`warning`/`success` (and `background` for the glyph) from
`require("theme.colourme")`, so the traffic-light colours follow the scheme. The
`warning` key was added to the template (`base0A` → ANSI yellow → `#febc2e`).

### Ghostty

Keep the hand-rolled `xdg.configFile."ghostty/config".text` (avoids churn in
`tmux.nix`), adding `theme = Luka`. Do **not** use HM's `themes.Luka` (a store
symlink `colourme` couldn't overwrite); the real `themes/Luka` is created by
`colourme` thanks to §1. Reload via `pkill -USR2 ghostty` (Ghostty re-reads
config on `SIGUSR2`).

### Quickshell

Implemented. `configs/quickshell/_Shared/Singletons/Colours.qml` is a
`FileView` (`watchChanges: true`, `onFileChanged: reload()`) whose
`JsonAdapter` maps `~/.local/state/colourme/colours.json` onto `string`
properties; the singleton re-exposes them as the `color` values the shell
reads. `Theme.qml` is unchanged (`colour: Colours`). A scheme switch updates
every surface instantly — there is no post_hook and no restart.

The adapter's declared defaults are the committed fallback palette, so the
shell is themed before the first seed/colourme run and if the file is ever
missing or unparseable. Keep the keys in sync with
`configs/colourme/templates/quickshell.json`.

The standalone `lockdaemon/` config reaches the same singleton through its
`_Shared` symlink, so the lock screen follows the scheme as well.

Quickshell wiring: enable `programs.quickshell` with
`activeConfig = "Pill"` and `configs.Pill` set to an out-of-store symlink of
`configs/quickshell` (so the QML stays live-editable). The JSON seam means
nothing generated lands in that tree.

### Zen Browser

Implemented. `configs/colourme/templates/zen_browser.css` is written to
`~/.local/state/colourme/zen-userChrome.css`. Zen applies `userChrome.css` at
startup but never reloads it, so `modules/users/features/zen-browser.nix` adds
a small autoconfig module to the *unwrapped* Zen package (the browser resolves
its application directory there; the nixpkgs wrapper only symlinks the files):

- `defaults/pref/00-colourme-autoconfig.js` sets
  `general.config.filename = "colourme.cfg"` and disables the autoconfig
  sandbox. The `00-` name keeps it clear of the wrapper's own autoconfig.js.
- `colourme.cfg` registers the profile's `chrome/colourme/chrome.manifest` and
  imports `chrome://colourme/content/colourme.sys.mjs`.
- That module registers the runtime file as a USER_SHEET and polls its mtime
  once a second, re-registering with a cache-busting query when `colourme`
  rewrites it — live update with no post_hook and no restart.

Home Manager activation resolves the default profile from `profiles.ini` and
symlinks `chrome/userChrome.css` at the runtime file, plus the module and
manifest under `chrome/colourme/`. The module stats the runtime file itself
rather than the symlink, because `nsIFile.lastModifiedTime` does not follow
symlinks.

The template paints the sidebar through
`--zen-navigator-toolbox-background` and the top toolbar through a direct
`#zen-appcontent-navbar-wrapper` rule: Zen moves the toolbar outside
`#navigator-toolbox` and gives it no background of its own, so the toolbox
variable alone never reaches it.

If Zen ever ships native userChrome.css reloading (or a Sine-style reload hook),
drop the `extraPrefs`/autoconfig override and let colourme write the profile
file directly.

### Neovim

Implemented. `configs/colourme/templates/nvim.lua` and `nvim-base16.lua` write
`~/.local/state/colourme/nvim/set_colourscheme.lua` and `palette.lua`.
The config lives at `configs/nvim` (symlinked to `~/.config/nvim`) and keeps
two thin shims at `lua/ui/set_colourscheme.lua` and
`lua/ui/palettes/colourme.lua` that `loadfile` the runtime files and fall back
to Gruvbox, so colourme never writes inside the repo. There is no watcher: a
running Neovim keeps its palette until restarted.

### Spicetify

Implemented. Spotify comes from nixpkgs (D42) and lives in the immutable
store, while spicetify patches assets next to the app. The `spotify` launcher
(`modules/users/features/spicetify.nix`) therefore keeps a writable copy at
`~/.local/share/spotify-spiced`: it stamps the copy with the Spotify store
path, rebuilds it after an update (`cp --reflink=auto`), applies the theme from
`~/.config/spicetify`, then execs the copy. The wrapper's environment
(`LD_LIBRARY_PATH`, GIO/GDK modules, Wayland flags) is preserved by rewriting
the store wrapper's one hardcoded share path.

`configs/colourme/templates/spicetify-matte.ini` renders Matte's `color.ini`;
Matte's `user.css` is symlinked from the dotfiles checkout (desktop-only
in-scope, like `~/.wallpaper`). `config-xpui.ini` is seeded once by activation
because spicetify writes its `[Backup]` section into it. There is no
`post_hook`: the launcher starts the client with a loopback DevTools endpoint
and runs `spicetify watch -s`, whose poller notices the rewrite and reloads the
window — a live switch while Spotify is open, or the next launch applies it.
`spicetify-nix` was rejected; see D58.

### Wallpaper

Implemented. Each scheme file carries `wallpaper = "~/.wallpaper/<scheme>/<file>"`.
The `[waypaper]` section renders waypaper's state file
(`~/.config/waypaper/wallpaper.ini`) and restores it with
`waypaper --restore`, whose hyprpaper backend repaints all outputs live.
`modules/users/features/wallpaper.nix` installs waypaper and symlinks
`~/.wallpaper` at `~/dotfiles/wallpaper/.wallpaper` — 59 MB of images kept in
the dotfiles checkout rather than vendored for now. A machine without that
checkout (e.g. the test VM) gets a dangling symlink and no wallpapers; vendor a
curated set before the removal path needs it. Waypaper's settings live in
`~/.config/waypaper/config.ini` as ordinary runtime state; hyprpaper is the
only installed backend, so waypaper selects it automatically.

At login, `my.hyprland.autostartLate` runs
`configs/hypr/scripts/wallpaper-restore.sh` after `services.wallpaper =
hyprpaper`; the script waits for hyprpaper's IPC socket, repairs a stale
`HYPRLAND_INSTANCE_SIGNATURE` (long-lived panes from an older session) and then
restores the saved state, so the wallpaper is right on the first frame. The
same script is the colourme `post_hook`, which is why a scheme switch also works
from a pane that predates the current compositor. The Quickshell lock screen
reads the same state file for its backdrop.

## Defaults — strategy A (build-time render, seed-if-absent)

A fresh install must look right with no `colourme` run. Generate the defaults
hermetically from the same templates, then copy them in only if missing.

1. **Render (build time).** A derivation runs the packaged `colourme` with
   `HOME=/homeless-shelter` (so `~` expands deterministically):

   ```nix
   runCommand "colourme-defaults" { nativeBuildInputs = [ colourme ]; } ''
     HOME=/homeless-shelter colourme \
       --config ${./configs/colourme/config.toml} \
       --schemes-dir ${./configs/colourme/schemes} \
       --dest-root "$out" \
       --no-hooks \
       ${config.my.theme.defaultScheme}
   ''
   ```

   Produces e.g. `$out/.config/hypr/theme/colourme.lua`,
   `$out/.config/ghostty/themes/Luka`,
   `$out/.local/state/colourme/colours.json`.

2. **Seed (activation).** A `home.activation` step copies each default to its
   runtime path. A per-file **stamp** in
   `~/.local/state/colourme/seeded/` holds the bytes last seeded, so the step
   distinguishes "still the default" from "written by colourme":

   - absent runtime file → install the default and record the stamp;
   - runtime file byte-identical to its stamp → refresh from the current
     default (template/`defaultScheme` changes propagate on rebuild);
   - runtime file differs from its stamp → leave it alone (colourme owns it).

   ```sh
   seed() {
     if [ ! -e "$dst" ]; then
       install -Dm644 "$src" "$dst"; install -Dm644 "$src" "$stamp"
     elif cmp -s "$dst" "$stamp"; then        # still seed-owned
       install -Dm644 "$src" "$dst"; install -Dm644 "$src" "$stamp"
     fi                                        # else: colourme owns it
   }
   ```

   The first activation after the stamp mechanism was introduced backs the
   pre-existing file up to `<stamp>.pre-stamp`, then treats it as seed-owned
   once. (`install -D` also handles the parent dirs.)

3. **Default scheme is a Nix option:** `my.theme.defaultScheme` (default e.g.
   `"Gruvbox"`), so the choice is declarative and reviewable.

Because the default is rendered fresh on every rebuild from the pinned
templates, it cannot drift — there are no committed generated files to keep in
sync. The Quickshell fallback lives in `Colours.qml` as the `JsonAdapter`
defaults (small, hand-written).

### Installed as a package

The packaged `colourme` is in `home.packages`, so `colourme <scheme>` works from
any shell. It reads `~/.config/colourme` (the out-of-store symlink to
`configs/colourme`), so schemes and templates stay editable live, and it writes
all of the runtime seams directly — no wrapper needed.

## Sequencing

1. Implement colourme changes §1–§4, §7 (+ optionally §5, §6). *(done)*
2. Add a flake to colourme exposing a package. *(done)*
3. Add `inputs.colourme` to `flake.nix`; build the defaults derivation. *(done)*
4. Commit `configs/colourme/` + the `colourme.nix` symlink feature. *(done)*
5. Re-point the app seams: hypr `settings.nix`, ghostty config, quickshell
   `Colours.qml`, Zen `userChrome.css`, Neovim shims. *(done)*
6. Add `my.theme.defaultScheme` + the activation seed. *(done)*
7. Add D27 to `DECISIONS.md` (done) and verify on the test VM.

## Open questions

- Whether `colourme` should also touch the *live* default when
  `defaultScheme` changes in Nix, or strictly seed-if-absent (current plan:
  seed-if-absent, never clobber).

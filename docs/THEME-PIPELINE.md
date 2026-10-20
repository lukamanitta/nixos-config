# Theme pipeline (colourme × Home Manager)

Plan for integrating `colourme` into this flake. Status: **implemented for the
Hyprland and Ghostty seams**; the Quickshell seam below is still pending.

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

Three seams, all writing **outside git**:

| App | Nix points at | `colourme` writes | Reload |
|---|---|---|---|
| Hyprland | `require("theme.colourme")` in generated lua | `~/.config/hypr/theme/colourme.lua` | `post_hook = "hyprctl reload"` |
| Ghostty | `theme = Luka` in config | `~/.config/ghostty/themes/Luka` | `post_hook = "pkill -USR2 ghostty"` |
| Quickshell | `FileView` watcher in `Colours.qml` | `~/.local/state/colourme/colours.json` | (none — file watch is instant) |

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
post_hook = "hyprctl reload"

[ghostty]
template = "templates/ghostty"
destination = "~/.config/ghostty/themes/Luka"
post_hook = "pkill -USR2 ghostty"

[quickshell]
template = "templates/quickshell.json"
destination = "~/.local/state/colourme/colours.json"
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

### Quickshell (seam rework)

Goal: keep generated colour data out of git and update instantly. Replace the
current "overwrite `Colours.qml`" approach with a runtime JSON + file watch:

- `colourme` writes `~/.local/state/colourme/colours.json` (gitignored by
  virtue of living outside the repo).
- `configs/quickshell/_Shared/Singletons/Colours.qml` becomes a `FileView`
  watcher (mirror the existing `Dyn.qml` pattern) that parses that JSON with
  `watchChanges: true` and exposes the same property names as today. `Theme.qml`
  is unchanged (`colour: Colours`).
- If the JSON is missing/unparseable (before the seed runs), fall back to a
  committed `_Shared/Singletons/colours.default.json` with the same shape, so
  Quickshell never renders unthemed.
- No `post_hook`; the watch makes it instant.

Quickshell wiring: enable `programs.quickshell` with
`activeConfig = "Pill"` and `configs.Pill` set to an out-of-store symlink of
`configs/quickshell` (so the QML stays live-editable). The JSON seam means
nothing generated lands in that tree.

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
sync. The only committed "default" is Quickshell's `colours.default.json`
fallback (hand-written, small).

### Not installed on the system

The packaged `colourme` is a **build input only** (for the defaults
derivation); it is not in `home.packages`. For live switching you run the clone
(`~/projects/code/colourme`); a Nix-provided wrapper can come later.

## Sequencing

1. Implement colourme changes §1–§4, §7 (+ optionally §5, §6). *(done)*
2. Add a flake to colourme exposing a package. *(done)*
3. Add `inputs.colourme` to `flake.nix`; build the defaults derivation. *(done)*
4. Commit `configs/colourme/` + the `colourme.nix` symlink feature. *(done)*
5. Re-point the three seams: hypr `settings.nix`, ghostty config, quickshell
   `Colours.qml` + `colours.default.json`. *(hypr + ghostty done; quickshell
   pending)*
6. Add `my.theme.defaultScheme` + the activation seed. *(done)*
7. Add D27 to `DECISIONS.md` (done) and verify on the test VM.

## Open questions

- Exact Quickshell property/path plumbing in `Colours.qml` (confirm against
  `Dyn.qml` when implementing).
- Whether `colourme` should also touch the *live* default when
  `defaultScheme` changes in Nix, or strictly seed-if-absent (current plan:
  seed-if-absent, never clobber).
- Whether to add a thin `theme` wrapper (`colourme <scheme>` + PATH) once
  colourme is packaged.

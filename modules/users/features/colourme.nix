{
  pkgs,
  lib,
  inputs,
  config,
  ...
}:

let
  cfg = config.my.theme;

  colourme = inputs.colourme.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Static, non-host-varying config stays in its native language under
  # configs/ and is symlinked out-of-store so schemes/templates stay editable
  # live (D25). Assumes the flake is checked out at ~/nixos-config.
  colourmeConfigDir = ../../../configs/colourme;

  # Render the default theme files hermetically at build time. colourme is a
  # build-time input only, so it never lands in the user or system closure.
  defaultThemes =
    pkgs.runCommand "colourme-default-themes"
      {
        nativeBuildInputs = [ colourme ];
      }
      ''
        HOME=/homeless-shelter ${lib.getExe colourme} \
          --config ${colourmeConfigDir}/config.toml \
          --schemes-dir ${colourmeConfigDir}/schemes \
          --dest-root "$out" \
          --no-hooks \
          ${cfg.defaultScheme}
      '';
in
{
  options.my.theme.defaultScheme = lib.mkOption {
    type = lib.types.str;
    default = "Gruvbox";
    description = "Scheme rendered as the default theme on a fresh install.";
  };

  config = {
    xdg.configFile."colourme".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/configs/colourme";

    # Seed the runtime theme files from the build-time defaults. A stamp holds
    # the bytes we last seeded, so a rebuild refreshes a file that is still
    # seed-owned (e.g. a template gained a key) while a theme written by
    # colourme differs from its stamp and is left alone.
    home.activation.seedColourmeTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      _seed_colourme() {
        _src="$1"
        _dst="$2"
        _stamp="$3"

        if [ ! -e "$_dst" ]; then
          run install -Dm644 "$_src" "$_dst"
          run install -Dm644 "$_src" "$_stamp"
          return
        fi

        # Migration from the old seed-if-absent policy: no stamp exists yet.
        # Keep the previous file and treat it as seed-owned once.
        if [ ! -e "$_stamp" ]; then
          run install -Dm644 "$_dst" "$_stamp.pre-stamp"
          run install -Dm644 "$_src" "$_dst"
          run install -Dm644 "$_src" "$_stamp"
          return
        fi

        if ${pkgs.diffutils}/bin/cmp -s "$_dst" "$_stamp"; then
          run install -Dm644 "$_src" "$_dst"
          run install -Dm644 "$_src" "$_stamp"
        fi
      }
      _seed_colourme ${defaultThemes}/.config/hypr/theme/colourme.lua \
        "$HOME/.config/hypr/theme/colourme.lua" \
        "$HOME/.local/state/colourme/seeded/hypr.lua"
      _seed_colourme ${defaultThemes}/.config/ghostty/themes/Luka \
        "$HOME/.config/ghostty/themes/Luka" \
        "$HOME/.local/state/colourme/seeded/ghostty-Luka"
      _seed_colourme ${defaultThemes}/.local/state/colourme/colours.json \
        "$HOME/.local/state/colourme/colours.json" \
        "$HOME/.local/state/colourme/seeded/colours.json"
      _seed_colourme ${defaultThemes}/.config/gtk-3.0/colourme-gtk.css \
        "$HOME/.config/gtk-3.0/colourme-gtk.css" \
        "$HOME/.local/state/colourme/seeded/gtk3.css"
      _seed_colourme ${defaultThemes}/.config/gtk-4.0/colourme-gtk.css \
        "$HOME/.config/gtk-4.0/colourme-gtk.css" \
        "$HOME/.local/state/colourme/seeded/gtk4.css"
      _seed_colourme ${defaultThemes}/.config/waybar/colourme-waybar.css \
        "$HOME/.config/waybar/colourme-waybar.css" \
        "$HOME/.local/state/colourme/seeded/waybar.css"
    '';
  };
}

{ pkgs, lib, inputs, config, ... }:

let
  cfg = config.my.theme;

  colourme = inputs.colourme.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Static, non-host-varying config stays in its native language under
  # configs/ and is symlinked out-of-store so schemes/templates stay editable
  # live (D25). Assumes the flake is checked out at ~/nixos-config.
  colourmeConfigDir = ../../../configs/colourme;

  # Render the default theme files hermetically at build time. colourme is a
  # build-time input only, so it never lands in the user or system closure.
  defaultThemes = pkgs.runCommand "colourme-default-themes" {
    nativeBuildInputs = [ colourme ];
  } ''
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
      config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/nixos-config/configs/colourme";

    # Seed the runtime theme files from the build-time defaults, but never
    # clobber a theme colourme has already written (seed only if absent).
    home.activation.seedColourmeTheme =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _seed_colourme() {
          if [ ! -e "$2" ]; then
            run install -Dm644 "$1" "$2"
          fi
        }
        _seed_colourme ${defaultThemes}/.config/hypr/theme/colourme.lua \
          "$HOME/.config/hypr/theme/colourme.lua"
        _seed_colourme ${defaultThemes}/.config/ghostty/themes/Luka \
          "$HOME/.config/ghostty/themes/Luka"
        _seed_colourme ${defaultThemes}/.local/state/colourme/colours.json \
          "$HOME/.local/state/colourme/colours.json"
        _seed_colourme ${defaultThemes}/.config/gtk-3.0/colourme-gtk.css \
          "$HOME/.config/gtk-3.0/colourme-gtk.css"
        _seed_colourme ${defaultThemes}/.config/gtk-4.0/colourme-gtk.css \
          "$HOME/.config/gtk-4.0/colourme-gtk.css"
        _seed_colourme ${defaultThemes}/.config/waybar/colourme-waybar.css \
          "$HOME/.config/waybar/colourme-waybar.css"
      '';
  };
}

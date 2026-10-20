{
  config,
  lib,
  pkgs,
  ...
}:

# LitheDE toolkit cohesion: Adwaita *shapes* everywhere (adw-gtk3 for GTK3,
# Adwaita for GTK4/libadwaita, adwaita-qt6 for Qt), recoloured to the active
# colourme scheme at runtime. Icons/cursors are WhiteSur. See docs/LITHEDE.md.
let
  enabled = config.my.desktops.environment == "lithe";
  t = config.my.desktops.lithe.tokens;

  # The alternative set is the redesigned WhiteSur artwork (not the literal
  # macOS icon copies); bold panel icons match LitheDE's heavier UI face.
  whitesurIcons = pkgs.whitesur-icon-theme.override {
    alternativeIcons = true;
    boldPanelIcons = true;
  };

  # libadwaita/GTK4 read user CSS here; the colours themselves are written by
  # colourme at runtime into the imported file (the D27 seam).
  gtkCssImport = ''@import url("colourme-gtk.css");'' + "\n";
in
{
  config = lib.mkIf enabled {
    home.packages = with pkgs; [
      adw-gtk3
      whitesurIcons
      whitesur-cursors
      adwaita-qt6
      qt6Packages.qt6ct
    ];

    gtk = {
      enable = true;
      theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };
      iconTheme = {
        name = "WhiteSur-dark";
        package = whitesurIcons;
      };
      cursorTheme = {
        name = "WhiteSur-cursors";
        package = pkgs.whitesur-cursors;
      };
      font = {
        name = t.font.ui;
        size = t.font.size.ui;
      };
    };

    home.pointerCursor = {
      name = "WhiteSur-cursors";
      package = pkgs.whitesur-cursors;
      size = 24;
      gtk.enable = true;
    };

    xdg.configFile = {
      "gtk-3.0/gtk.css".text = gtkCssImport;
      "gtk-4.0/gtk.css".text = gtkCssImport;
      "gtk-4.0/gtk-dark.css".text = gtkCssImport;
    };

    # Qt6 uses the adwaita-qt style (Adwaita shapes) for the palette/fonts.
    home.sessionVariables.QT_STYLE_OVERRIDE = "adwaita";
  };
}

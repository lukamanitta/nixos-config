{
  config,
  lib,
  pkgs,
  ...
}:

# Spotify + spicetify. nixpkgs' Spotify lives in the immutable store and
# spicetify patches files next to the app, so the launcher keeps a writable
# copy under ~/.local/share and patches that. The copy is stamped with the
# Spotify store path and rebuilt after an update.
#
# colourme owns Themes/Matte/color.ini (see configs/colourme/config.toml). The
# launcher applies it at startup, then runs the client with a loopback
# DevTools endpoint and supervises `spicetify watch -s`, so a later colourme
# rewrite reloads the open window too.
let
  cfg = config.my.spicetify;

  spotify = pkgs.spotify;
  spicetify = pkgs.spicetify-cli;

  dataHome = config.xdg.dataHome;
  configHome = config.xdg.configHome;
  stateHome = config.xdg.stateHome;

  copyRoot = "${dataHome}/spotify-spiced";
  copyApp = "${copyRoot}/share/spotify";
  spicetifyConfig = "${configHome}/spicetify";
  spicetifyState = "${stateHome}/spicetify";
  spotifyPrefs = "${configHome}/spotify/prefs";

  quote = lib.escapeShellArg;

  launcher = pkgs.writeShellApplication {
    name = "spotify";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gnugrep
      pkgs.gnused
      pkgs.procps
      pkgs.util-linux
    ];
    text = ''
      copy=${quote copyRoot}
      app=${quote copyApp}
      src=${quote "${spotify}/share/spotify"}
      wrapper=${quote "${spotify}/bin/spotify"}
      conf=${quote spicetifyConfig}
      state=${quote spicetifyState}
      prefs=${quote spotifyPrefs}

      mkdir -p "$conf" "$state" ${quote (dirOf spotifyPrefs)}
      [ -e "$prefs" ] || : > "$prefs"
      export SPICETIFY_CONFIG="$conf"

      # A running client owns the copy. Let Spotify's single-instance handling
      # focus it instead of re-patching files underneath it.
      if pgrep -f "$copy/bin/spotify" >/dev/null; then
        exec "$copy/bin/spotify" "$@"
      fi

      # The flock keeps a double launch from syncing/applying concurrently.
      (
        flock 9

        # No stamp or no backup means a fresh copy: the Spotify package
        # changed, or the user cleared spicetify's state. Reflinks keep the
        # 370 MB copy cheap on btrfs.
        fresh=0
        if [ "$(cat "$copy/.source" 2>/dev/null || true)" != ${quote "${spotify}"} ] ||
          [ ! -d "$state/Backup" ]; then
          fresh=1
          rm -rf "$copy"
          mkdir -p "$app" "$copy/bin"
          cp -a --reflink=auto "$src/." "$app/"
          chmod -R u+rwX "$app"
          # The store wrapper only differs by the share path it execs, so keep
          # its environment (LD_LIBRARY_PATH, GIO/GDK modules, Wayland flags)
          # and point the exec at the writable copy. spicetify patches the copy.
          sed "s|$src|$app|g" "$wrapper" > "$copy/bin/spotify"
          chmod +x "$copy/bin/spotify"
          printf '%s\n' ${quote "${spotify}"} > "$copy/.source"
          rm -rf "$state/Backup"
        fi

        if [ "$fresh" -eq 1 ]; then
          ${lib.getExe spicetify} --no-restart backup apply >"$state/apply.log" 2>&1 || true
        else
          ${lib.getExe spicetify} --no-restart apply >"$state/apply.log" 2>&1 || true
        fi
      ) 9>"$state/launch.lock"

      # Run with a loopback DevTools endpoint so spicetify's watcher can reload
      # the window when colourme rewrites color.ini while the client is open.
      "$copy/bin/spotify" --remote-debugging-port=9222 '--remote-allow-origins=*' "$@" &
      client=$!

      # Start the watcher only once the endpoint exposes a Spotify target:
      # spicetify's own watch mode restarts the client when it cannot find one.
      watcher=
      for _ in $(seq 1 60); do
        if curl -sf http://127.0.0.1:9222/json/list 2>/dev/null | grep '"url".*spotify' >/dev/null; then
          ${lib.getExe spicetify} watch -s >"$state/watch.log" 2>&1 &
          watcher=$!
          break
        fi
        kill -0 "$client" 2>/dev/null || break
        sleep 0.25
      done

      wait "$client"
      status=$?
      if [ -n "$watcher" ]; then
        kill "$watcher" 2>/dev/null || true
        wait "$watcher" 2>/dev/null || true
      fi
      exit "$status"
    '';
  };

  # Seeded once: spicetify rewrites [Backup] in this file, so it cannot be a
  # store symlink. The theme itself is seeded by the colourme module.
  configSeed = pkgs.writeText "spicetify-config-xpui.ini" ''
    [Setting]
    spotify_path           = ${copyApp}/
    prefs_path             = ${spotifyPrefs}
    inject_theme_js        = 1
    inject_css             = 1
    overwrite_assets       = 0
    check_spicetify_update = 0
    current_theme          = Matte
    color_scheme           = colourme
    replace_colors         = 1
    spotify_launch_flags   =

    [Preprocesses]
    disable_sentry     = 1
    disable_ui_logging = 1
    remove_rtl_rule    = 1
    expose_apis        = 1

    [AdditionalOptions]
    extensions            =
    custom_apps           =
    sidebar_config        = 0
    home_config           = 1
    experimental_features = 1
  '';
in
{
  options.my.spicetify = {
    enable = lib.mkEnableOption "Spotify with spicetify and the colourme theme";
  };

  config = lib.mkIf cfg.enable {
    # `spotify` from the home profile shadows the unspiced system binary, and
    # the desktop entry below shadows the system one (same ID).
    home.packages = [
      launcher
      spicetify
    ];

    home.activation.seedSpicetifyConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e ${quote "${spicetifyConfig}/config-xpui.ini"} ]; then
        run install -Dm644 ${configSeed} ${quote "${spicetifyConfig}/config-xpui.ini"}
      fi
    '';

    # Matte's stylesheet is not themed; keep the dotfiles copy live-editable.
    # A machine without the checkout gets a dangling link, like ~/.wallpaper.
    home.file.".config/spicetify/Themes/Matte/user.css".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/spicetify/.config/spicetify/Themes/Matte/user.css";

    xdg.desktopEntries.spotify = {
      name = "Spotify";
      genericName = "Music Player";
      comment = "Play music and podcasts";
      exec = "${launcher}/bin/spotify %U";
      icon = "spotify";
      categories = [
        "AudioVideo"
        "Audio"
        "Player"
        "Music"
      ];
      mimeType = [ "x-scheme-handler/spotify" ];
      settings.StartupWMClass = "spotify";
    };
  };
}

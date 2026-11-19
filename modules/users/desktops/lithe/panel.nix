{
  config,
  lib,
  pkgs,
  ...
}:

# LitheDE top bar (waybar): one fused strip (DECISIONS D33).
#
#   left   — launcher (magnifier) + dock of running windows
#   centre — workspace dots (occupied only, click to switch)
#   right  — tray + clock + control centre
#
# There is no separate taskbar next to a workspace row: the workspace module is
# reduced to status dots, and the dock is the only clickable window list.
# Geometry comes from the LitheDE tokens; colours from the colourme waybar seam.
#
# The "fade the other apps while the focused window is maximized" rule cannot
# be expressed in GTK CSS (no `:has()`), so a tiny watcher follows Hyprland's
# event socket and rewrites `~/.config/waybar/lithede-state.css` — the same
# runtime-writable seam pattern as colourme (D27): Nix owns the structure, the
# compositor's live state owns the one conditional rule.
let
  enabled = config.my.desktops.environment == "lithe";
  t = config.my.desktops.lithe.tokens;
  toLua = lib.generators.toLua { };
  launcher =
    if config.my.desktop.programs.launcher != null then
      config.my.desktop.programs.launcher
    else
      "hyprlauncher";

  # Waybar cannot chain actions per mouse button, and `maximize` does not move
  # focus (Hyprland's foreign-toplevel request only sets the fullscreen mode).
  # So the dock contracts to: left = focus, middle = close, right = maximize
  # toggle. The green traffic light is the primary maximize affordance.
  barState = pkgs.writeShellApplication {
    name = "lithede-bar-state";
    runtimeInputs = with pkgs; [
      hyprland
      jq
      socat
      procps
    ];
    text = ''
      out="${config.xdg.configHome}/waybar/lithede-state.css"
      mkdir -p "$(dirname "$out")"

      # A config reload also (re)starts us; take over from any previous
      # generation instead of silently losing to it.
      pidfile="''${XDG_RUNTIME_DIR:-/tmp}/lithede-bar-state.pid"
      if [ -f "$pidfile" ]; then
        old="$(cat "$pidfile" 2>/dev/null || true)"
        if [ -n "$old" ] && [ "$old" != "$$" ] && kill -0 "$old" 2>/dev/null; then
          kill "$old" 2>/dev/null || true
        fi
      fi
      echo "$$" > "$pidfile"
      trap 'rm -f "$pidfile"' EXIT

      if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        sock="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
      else
        sock=""
        for candidate in "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/hypr/*/.socket2.sock; do
          [ -S "$candidate" ] || continue
          sock="$candidate"
          break
        done
        # hyprctl needs the instance signature too; derive it from the socket so
        # the state query works even when started without the env var.
        if [ -n "$sock" ]; then
          discovered_sig="$(basename "$(dirname "$sock")")"
          export HYPRLAND_INSTANCE_SIGNATURE="$discovered_sig"
        fi
      fi
      [ -n "$sock" ] || { echo "lithede-bar-state: no Hyprland event socket" >&2; exit 1; }

      log="''${XDG_STATE_HOME:-$HOME/.local/state}/lithede/bar-state.log"
      mkdir -p "$(dirname "$log")"
      : > "$log"
      echo "start sig=''${HYPRLAND_INSTANCE_SIGNATURE:-} sock=$sock" >> "$log"

      last="__init__"

      write_state() {
        local fs new
        # `fullscreen` is Hyprland's internal state; waybar's foreign-toplevel
        # maximize request only sets the client state. Check both.
        fs="$(hyprctl activewindow -j 2>/dev/null | jq -r 'if ((.fullscreen // 0) != 0) or ((.fullscreenClient // 0) != 0) then 1 else 0 end' 2>/dev/null || echo 0)"
        echo "state fs=''${fs:-?}" >> "$log"
        if [ "''${fs:-0}" = "1" ]; then
          # GTK CSS has no `:not()`/`:has()`; fade everything, then restore the
          # focused entry (the generated file is imported before the base CSS,
          # and no later rule sets opacity).
          new="$(printf '%s\n' '#taskbar button { opacity: 0.35; }' '#taskbar button.active { opacity: 1; }')"
        else
          new=""
        fi

        # Only rewrite + reload waybar when the state actually flipped.
        if [ "$new" != "$last" ]; then
          printf '%s\n' "$new" > "$out"
          pkill -SIGUSR2 -x waybar || true
        fi
        last="$new"
      }

      write_state
      socat -U - "UNIX-CONNECT:$sock" | while IFS= read -r line; do
        case "$line" in
          activewindow\>\>* | fullscreenstate\>\>* | fullscreen\>\>*) write_state ;;
        esac
      done
    '';
  };

  barConfig = {
    layer = "top";
    position = "top";
    height = 34;
    spacing = t.space.sm;
    "modules-left" = [
      "custom/launcher"
      "wlr/taskbar"
    ];
    "modules-center" = [ "hyprland/workspaces" ];
    "modules-right" = [
      "tray"
      "clock"
      "custom/controlcenter"
    ];
    "custom/launcher" = {
      # Magnifier: the button opens hyprlauncher's search, it does not list apps.
      format = "";
      tooltip = false;
      "on-click" = launcher;
    };
    "wlr/taskbar" = {
      format = "{icon}";
      "icon-size" = 18;
      "tooltip-format" = "{title}";
      # Stable order with same-app windows adjacent; `active-first` would
      # reshuffle the row on every focus change.
      "sort-by-app-id" = true;
      "on-click" = "activate";
      "on-click-middle" = "close";
      "on-click-right" = "maximize";
    };
    "hyprland/workspaces" = {
      # Five fixed slots so a new workspace never shifts the row; empty ones
      # are just dim dots (D33).
      format = "{icon}";
      "format-icons" = {
        default = "●";
      };
      "persistent-workspaces" = {
        "*" = [
          1
          2
          3
          4
          5
        ];
      };
      "all-outputs" = false;
      "show-special" = false;
      tooltip = true;
      "tooltip-format" = "workspace {name}";
    };
    tray = {
      "icon-size" = 18;
      spacing = 8;
    };
    clock = {
      format = "{:%a %H:%M}";
      "tooltip-format" = "{:%A %d %B %Y}";
    };
    "custom/controlcenter" = {
      format = "⏻";
      tooltip = false;
      "on-click" = "swaync-client -t -sw";
    };
  };
in
{
  config = lib.mkIf enabled {
    home.packages = [ barState ];

    # Started with Hyprland, so HYPRLAND_INSTANCE_SIGNATURE is already set.
    my.hyprland.autostart = lib.mkAfter [ (lib.getExe barState) ];

    # `hyprland.start` only fires at login; also (re)start on config reload so
    # a home-manager switch alone picks up changes. The script takes over from
    # any instance started by an older generation.
    wayland.windowManager.hyprland.extraConfig = ''
      hl.on("config.reloaded", function()
        hl.exec_cmd(${toLua (lib.getExe barState)})
      end)
    '';

    # A switch replaces waybar's CSS on disk but nothing told the running bar;
    # reload it after the colourme files are seeded.
    home.activation.reloadWaybar =
      lib.hm.dag.entryAfter
        [
          "writeBoundary"
          "seedColourmeTheme"
        ]
        ''
          if [ -e "$HOME/.config/waybar/colourme-waybar.css" ]; then
            pkill -SIGUSR2 -x waybar || true
          fi
        '';

    xdg.configFile = {
      "waybar/config".source = (pkgs.formats.json { }).generate "waybar-config.json" barConfig;

      "waybar/style.css".text = ''
        @import url("colourme-waybar.css");
        @import url("lithede-state.css");

        * {
          font-family: "${t.font.ui}", "${t.font.glyph}";
          font-size: ${toString t.font.size.ui}px;
          border: none;
          border-radius: 0;
          min-height: 0;
          padding: 0 ${toString t.space.sm}px;
        }

        window#waybar {
          background: alpha(@colourme_bg, ${toString t.opacity.panel});
          color: @colourme_fg;
        }

        /* Workspace dots — fixed 4px slots, status not numbers. Occupied slots
           are lit; empty and not-yet-created ones stay dim; active is accent. */
        #workspaces button {
          color: alpha(@colourme_fg, 0.35);
          background: transparent;
          padding: 0 ${toString t.space.xs}px;
          min-width: 0;
          min-height: 0;
          font-size: 4px;
        }

        #workspaces button.empty {
          color: alpha(@colourme_fg, 0.12);
        }

        #workspaces button.active {
          color: @colourme_accent;
        }

        #custom-launcher {
          color: @colourme_accent;
          font-weight: bold;
        }

        /* Dock: the focused window gets a straight 2px underline with rounded
           caps (bottom-corner radius clips the border ends), nothing tinted. */
        #taskbar button {
          background: transparent;
          padding: 0 ${toString t.space.xs}px;
          border-bottom: 2px solid transparent;
          border-radius: 0 0 2px 2px;
        }

        #taskbar button.active {
          border-bottom-color: @colourme_accent;
        }

        #tray,
        #custom-controlcenter {
          color: @colourme_fg;
        }
      '';
    };
  };
}

{ lib, pkgs, ... }:

# Shared compositor feature. Owns everything DE-agnostic: variables, binds,
# monitors, workspace/window rules, env, autostart. The visual half of the
# config (general/decoration/group/animations) belongs to each DE — see
# modules/users/desktops/<slug>/.
{
  imports = [
    ./variables.nix
    ./settings.nix
    ./binds
    ./monitors.nix
    ./workspacerules.nix
    ./env.nix
    ./windowrules.nix
    ./autostart.nix
  ];

  options.my.hyprland = {
    monitors = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = "Hyprland monitor rules for this host.";
    };

    workspaceRules = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [ ];
      description = "Hyprland workspace rules for this host (e.g. workspace→monitor).";
    };

    autostart = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Commands started on hyprland.start, before the service roles.";
    };

    autostartLate = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Commands started on hyprland.start after the service roles, for things
        that need those services (e.g. restoring a wallpaper through
        hyprpaper).
      '';
    };
  };

  config = {
    home.packages = [ pkgs.xdg-terminal-exec ];

    # The polkit *mechanism* is system-wide, but GUI apps need an agent to
    # raise the password prompt; the Arch dotfiles started hyprpolkitagent
    # from autostart.
    services.hyprpolkitagent.enable = true;

    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      portalPackage = null;
      configType = "lua";
    };

    # Home Manager's own hyprland reload shells out to a bare `jq`, which is
    # frequently absent from the activation PATH — the reload loop then finds
    # no instances and the config silently stays stale until re-login. Do it
    # ourselves with absolute paths so a switch always applies.
    #
    # Order after `seedColourmeTheme`: reloading while the runtime theme file
    # is absent fails the whole config (`module 'theme.colourme' not found`).
    # The existence guard keeps a bad ordering from ever applying a broken
    # config again.
    home.activation.reloadHyprlandConfig =
      lib.hm.dag.entryAfter
        [
          "writeBoundary"
          "seedColourmeTheme"
        ]
        ''
          hyprctl=${pkgs.hyprland}/bin/hyprctl
          jq=${pkgs.jq}/bin/jq
          theme="$HOME/.config/hypr/theme/colourme.lua"
          if [ ! -e "$theme" ]; then
            echo "reloadHyprlandConfig: $theme is missing; skipping reload" >&2
          elif [ -d "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr" ] || [ -d /tmp/hypr ]; then
            for instance in $("$hyprctl" instances -j 2>/dev/null | "$jq" -r '.[].instance' 2>/dev/null); do
              "$hyprctl" -i "$instance" reload config-only || true
            done
          fi
        '';
  };
}

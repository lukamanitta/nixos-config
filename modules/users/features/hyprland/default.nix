{ lib, ... }:

{
  imports = [
    ../hyprland-ecosystem.nix
    ./variables.nix
    ./settings.nix
    ./binds
    ./monitors.nix
    ./workspacerules.nix
    ./env.nix
    ./animations.nix
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
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    configType = "lua";
  };
}

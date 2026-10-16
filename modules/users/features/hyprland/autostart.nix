{ config, lib, ... }:

let
  services = config.my.desktop.services;
  toLua = lib.generators.toLua { };
  cmds =
    config.my.hyprland.autostart
    ++ lib.optional (services.clipboardWatcher != null) services.clipboardWatcher
    ++ lib.optional (services.idle != null) services.idle
    ++ lib.optional (services.notification != null) services.notification
    ++ lib.optional (services.wallpaper != null) services.wallpaper
    ++ lib.optional (services.statusBar != null) services.statusBar
    ++ lib.optional (services.removableMedia != null) services.removableMedia;
  body = lib.concatMapStrings (c: "  hl.exec_cmd(${toLua c})\n") cmds;
in
lib.mkIf (cmds != [ ]) {
  wayland.windowManager.hyprland.settings.on = {
    _args = [
      "hyprland.start"
      (lib.generators.mkLuaInline "function()\n${body}end")
    ];
  };
}

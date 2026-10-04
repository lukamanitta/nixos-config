{ config, lib, ... }:

let
  p = config.my.desktop.programs;
  lua = lib.generators.mkLuaInline;
  key = k: lua ''mod .. " + ${k}"'';
  exec = cmd: lua "hl.dsp.exec_cmd(${lib.generators.toLua cmd})";
  bind = k: cmd: {
    _args = [
      (key k)
      (exec cmd)
    ];
  };
in
{
  wayland.windowManager.hyprland.settings.bind =
    [
      {
        _args = [
          (key "RETURN")
          (exec "xdg-terminal-exec")
        ];
      }
    ]
    ++ lib.optional (p.fileExplorer != null) (bind "E" p.fileExplorer)
    ++ lib.optional (p.browser != null) (bind "B" p.browser)
    ++ lib.optional (p.launcher != null) (bind "SPACE" p.launcher)
    ++ lib.optional (p.clipboardPicker != null) (bind "V" p.clipboardPicker)
    ++ lib.optional (p.lock != null) (bind "L" p.lock);
}

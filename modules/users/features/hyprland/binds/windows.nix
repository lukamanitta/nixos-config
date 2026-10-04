{ lib, ... }:

let
  lua = lib.generators.mkLuaInline;
  key = k: lua ''mod .. " + ${k}"'';
  bind = k: disp: {
    _args = [
      (key k)
      (lua disp)
    ];
  };
in
{
  wayland.windowManager.hyprland.settings.bind = [
    (bind "Q" "hl.dsp.window.close()")
    (bind "F" ''hl.dsp.window.float({ action = "toggle" })'')
    {
      _args = [
        (key "SHIFT + F")
        (lua ''hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })'')
      ];
    }
    (bind "h" ''hl.dsp.focus({ direction = "left" })'')
    (bind "l" ''hl.dsp.focus({ direction = "right" })'')
    (bind "k" ''hl.dsp.focus({ direction = "up" })'')
    (bind "j" ''hl.dsp.focus({ direction = "down" })'')
    {
      _args = [
        (lua ''"ALT + Tab"'')
        (lua ''hl.dsp.focus({ workspace = "previous" })'')
      ];
    }
    {
      _args = [
        (key "mouse:272")
        (lua "hl.dsp.window.drag()")
      ];
    }
    {
      _args = [
        (key "mouse:273")
        (lua "hl.dsp.window.resize()")
      ];
    }
  ];
}

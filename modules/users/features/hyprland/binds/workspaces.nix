{ lib, ... }:

let
  lua = lib.generators.mkLuaInline;
  pairs = [
    [ "1" 1 ]
    [ "2" 2 ]
    [ "3" 3 ]
    [ "4" 4 ]
    [ "5" 5 ]
    [ "6" 6 ]
    [ "7" 7 ]
    [ "8" 8 ]
    [ "9" 9 ]
    [ "0" 10 ]
  ];
  focus = pair: {
    _args = [
      (lua ''mod .. " + ${builtins.elemAt pair 0}"'')
      (lua "hl.dsp.focus({ workspace = ${toString (builtins.elemAt pair 1)} })")
    ];
  };
  move = pair: {
    _args = [
      (lua ''mod .. " + SHIFT + ${builtins.elemAt pair 0}"'')
      (lua "hl.dsp.window.move({ workspace = ${toString (builtins.elemAt pair 1)} })")
    ];
  };
in
{
  wayland.windowManager.hyprland.settings.bind = (map focus pairs) ++ (map move pairs) ++ [
    {
      _args = [
        (lua ''mod .. " + mouse_down"'')
        (lua ''hl.dsp.focus({ workspace = "e+1" })'')
      ];
    }
    {
      _args = [
        (lua ''mod .. " + mouse_up"'')
        (lua ''hl.dsp.focus({ workspace = "e-1" })'')
      ];
    }
  ];
}

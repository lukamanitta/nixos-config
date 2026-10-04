{ lib, ... }:

let
  lua = lib.generators.mkLuaInline;
  toLua = lib.generators.toLua { };
  exec = cmd: lua "hl.dsp.exec_cmd(${toLua cmd})";
  repeat = {
    locked = true;
    repeating = true;
  };
  locked = {
    locked = true;
  };
  bind = key: opts: cmd: {
    _args = [
      (lua ''"${key}"'')
      (exec cmd)
      opts
    ];
  };
in
{
  wayland.windowManager.hyprland.settings.bind = [
    (bind "XF86AudioRaiseVolume" repeat "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+")
    (bind "XF86AudioLowerVolume" repeat "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
    (bind "XF86AudioMute" repeat "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
    (bind "XF86AudioMicMute" repeat "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
    (bind "XF86MonBrightnessUp" repeat "brightnessctl -e4 -n2 set 5%+")
    (bind "XF86MonBrightnessDown" repeat "brightnessctl -e4 -n2 set 5%-")
    (bind "XF86AudioNext" locked "playerctl next")
    (bind "XF86AudioPause" locked "playerctl play-pause")
    (bind "XF86AudioPlay" locked "playerctl play-pause")
    (bind "XF86AudioPrev" locked "playerctl previous")
  ];
}

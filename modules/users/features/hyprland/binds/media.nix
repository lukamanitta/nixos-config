{ config, lib, ... }:

# Media/brightness keys. The commands route through the OSD provider when one
# is set (D3 role), so a DE with `services.osd = "swayosd-server"` gets
# swayosd-client feedback while a bare session just uses wpctl/brightnessctl.
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

  osd = config.my.desktop.services.osd;
  useSwayosd = osd != null && lib.hasPrefix "swayosd" osd;

  volUp =
    if useSwayosd then
      "swayosd-client --output-volume raise"
    else
      "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
  volDown =
    if useSwayosd then
      "swayosd-client --output-volume lower"
    else
      "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
  volMute =
    if useSwayosd then
      "swayosd-client --output-volume mute-toggle"
    else
      "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
  micMute =
    if useSwayosd then
      "swayosd-client --input-volume mute-toggle"
    else
      "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
  brightUp =
    if useSwayosd then "swayosd-client --brightness raise" else "brightnessctl -e4 -n2 set 5%+";
  brightDown =
    if useSwayosd then "swayosd-client --brightness lower" else "brightnessctl -e4 -n2 set 5%-";
in
{
  wayland.windowManager.hyprland.settings.bind = [
    (bind "XF86AudioRaiseVolume" repeat volUp)
    (bind "XF86AudioLowerVolume" repeat volDown)
    (bind "XF86AudioMute" repeat volMute)
    (bind "XF86AudioMicMute" repeat micMute)
    (bind "XF86MonBrightnessUp" repeat brightUp)
    (bind "XF86MonBrightnessDown" repeat brightDown)
    (bind "XF86AudioNext" locked "playerctl next")
    (bind "XF86AudioPause" locked "playerctl play-pause")
    (bind "XF86AudioPlay" locked "playerctl play-pause")
    (bind "XF86AudioPrev" locked "playerctl previous")
  ];
}

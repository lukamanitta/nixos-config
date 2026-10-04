{ config, ... }:

{
  wayland.windowManager.hyprland.settings.monitor = config.my.hyprland.monitors;
}

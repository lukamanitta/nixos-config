{
  config,
  lib,
  pkgs,
  ...
}:

# LitheDE control center (swaync): notification daemon *and* the mini settings
# menu — quick toggles, media, and the power actions (lock/logout/suspend/
# reboot/shutdown), plus a Wi-Fi toggle. The transient volume/brightness OSD is
# swayosd (services.osd). See docs/LITHEDE.md.
let
  enabled = config.my.desktops.environment == "lithe";

  swayncConfig = {
    positionX = "right";
    positionY = "top";
    layer = "overlay";
    "control-center-layer" = "top";
    "cssPriority" = "application";
    "notification-window-width" = 400;
    "control-center-width" = 400;
    "control-center-height" = 620;
    "keyboard-shortcuts" = true;
    "image-visibility" = "when-available";
    "transition-time" = 150;
    "hide-on-clear" = false;
    "hide-on-action" = true;
    "script-fail-notify" = true;
    widgets = [
      "title"
      "dnd"
      "mpris"
      "buttons-grid"
    ];
    "widget-config" = {
      title = {
        text = "Control Center";
        "clear-all-button" = true;
        "button-text" = "Clear";
      };
      dnd = {
        text = "Do Not Disturb";
      };
      mpris = {
        "image-size" = 96;
        "image-radius" = 12;
      };
      "buttons-grid" = {
        actions = [
          {
            label = "Lock";
            command = "hyprlock";
          }
          {
            label = "Logout";
            command = "hyprctl dispatch exit";
          }
          {
            label = "Suspend";
            command = "systemctl suspend";
          }
          {
            label = "Reboot";
            command = "systemctl reboot";
          }
          {
            label = "Shutdown";
            command = "systemctl poweroff";
          }
          {
            label = "Wi-Fi";
            type = "toggle";
            command = "nmcli radio wifi toggle";
            "update-command" = "nmcli radio wifi";
          }
        ];
      };
    };
  };
in
{
  config = lib.mkIf enabled {
    xdg.configFile."swaync/config.json".source =
      (pkgs.formats.json { }).generate "swaync-config.json"
        swayncConfig;
  };
}

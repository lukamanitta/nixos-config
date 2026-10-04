{ config, ... }:

{
  wayland.windowManager.hyprland.settings.workspace_rule = config.my.hyprland.workspaceRules;
}

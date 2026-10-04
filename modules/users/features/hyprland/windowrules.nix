{ ... }:

{
  wayland.windowManager.hyprland.settings.window_rule = [
    {
      name = "PiP-opacity";
      match = {
        title = "^(Picture-in-Picture)$";
      };
      float = true;
      pin = true;
      persistent_size = true;
      opaque = true;
      keep_aspect_ratio = true;
    }
    {
      name = "YouTube-opacity";
      match = {
        title = ".*YouTube.*";
      };
      opaque = true;
    }
    {
      name = "Affinity-opacity";
      match = {
        title = ".*Affinity.*";
      };
      opaque = true;
    }
    {
      name = "scratch";
      match = {
        title = "^scratch$";
      };
      float = true;
      pin = true;
      persistent_size = false;
      opaque = true;
    }
    {
      name = "suppress-maximize-events";
      match = {
        class = ".*";
      };
      suppress_event = "maximize";
    }
    {
      name = "fix-xwayland-drags";
      match = {
        class = "^$";
        title = "^$";
        xwayland = true;
        float = true;
        fullscreen = false;
        pin = false;
      };
      no_focus = true;
    }
    {
      name = "move-hyprland-run";
      match = {
        class = "hyprland-run";
      };
      move = "20 monitor_h-120";
      float = true;
    }
  ];
}

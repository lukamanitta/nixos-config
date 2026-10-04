{ ... }:

{
  wayland.windowManager.hyprland.settings.config = {
    general = {
      gaps_in = 4;
      gaps_out = {
        top = 3;
        right = 8;
        bottom = 8;
        left = 8;
      };
      border_size = 2;
      resize_on_border = false;
      allow_tearing = false;
      layout = "dwindle";
      col.active_border = "rgba(735c99ff)";
    };

    decoration = {
      rounding = 8;
      rounding_power = 2;
      active_opacity = 1.0;
      inactive_opacity = 0.96;
      blur = {
        enabled = true;
        size = 3;
        passes = 1;
        vibrancy = 0.1696;
      };
      shadow = {
        color = "rgba(15, 15, 15, 0.6)";
        color_inactive = "rgba(15, 15, 15, 0.3)";
        offset = [
          2
          2
        ];
        range = 11;
        render_power = 2;
      };
    };

    group.col.border_active = "rgba(735c99ff)";

    animations = {
      enabled = true;
    };

    master = {
      new_status = "master";
    };

    misc = {
      middle_click_paste = false;
      force_default_wallpaper = 0;
      disable_hyprland_logo = true;
      initial_workspace_tracking = 1;
      mouse_move_focuses_monitor = false;
    };

    input = {
      kb_layout = "us";
      kb_variant = "";
      kb_model = "";
      kb_options = "";
      kb_rules = "";
      repeat_delay = 180;
      repeat_rate = 35;
      follow_mouse = 2;
      sensitivity = -0.7;
      touchpad = {
        natural_scroll = false;
      };
    };

    cursor = {
      hide_on_key_press = true;
      no_warps = true;
    };
  };
}

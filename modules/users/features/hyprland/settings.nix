{ ... }:

# DE-agnostic Hyprland settings. Visual settings (general/decoration/group)
# and animations live with each DE under modules/users/desktops/<slug>/.
{
  wayland.windowManager.hyprland.settings.config = {
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

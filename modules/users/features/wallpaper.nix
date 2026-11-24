{
  config,
  lib,
  pkgs,
  ...
}:

let
  # hyprpaper starts with the wallpaper service role in the same
  # hyprland.start batch, so wait for its IPC socket before restoring the
  # saved waypaper state.
  restore = pkgs.writeShellApplication {
    name = "wallpaper-restore";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.waypaper
    ];
    text = ''
      state="''${XDG_CONFIG_HOME:-$HOME/.config}/waypaper/wallpaper.ini"
      [ -s "$state" ] || exit 0

      i=0
      while [ "$i" -lt 50 ]; do
        hyprctl hyprpaper listactive >/dev/null 2>&1 && break
        i=$((i + 1))
        sleep 0.1
      done

      exec waypaper --restore --state-file "$state"
    '';
  };
in
{
  home.packages = [ pkgs.waypaper ];

  # 59 MB of images: keep them in the dotfiles checkout for now instead of
  # vendoring them. The scheme files, waypaper state and the lock screen all
  # reference ~/.wallpaper.
  home.file.".wallpaper".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/wallpaper/.wallpaper";

  # The state file (which wallpaper) is rendered by colourme. Waypaper's own
  # settings stay runtime state in ~/.config/waypaper/config.ini: hyprpaper is
  # the only installed backend, so it is selected automatically, and the GUI
  # must remain able to save its folder/backend changes.

  # Runs after `services.wallpaper = hyprpaper`, which the DE sets.
  my.hyprland.autostartLate = [ "${restore}/bin/wallpaper-restore" ];
}

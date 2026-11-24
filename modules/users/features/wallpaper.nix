{
  config,
  pkgs,
  ...
}:

{
  home.packages = [ pkgs.waypaper ];

  # 59 MB of images: keep them in the dotfiles checkout for now instead of
  # vendoring them. The scheme files, waypaper state and the lock screen all
  # reference ~/.wallpaper.
  home.file.".wallpaper".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/wallpaper/.wallpaper";

  # Runs after `services.wallpaper = hyprpaper`, which the DE sets. The script
  # waits for hyprpaper's IPC socket and repairs a stale compositor
  # environment, so it is also safe to call from a long-lived shell.
  my.hyprland.autostartLate = [
    "${config.home.homeDirectory}/.config/hypr/scripts/wallpaper-restore.sh"
  ];
}

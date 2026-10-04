{ pkgs, ... }:

{
  programs.hyprland.enable = true;

  services.displayManager.sddm.enable = true;
  services.displayManager.defaultSession = "hyprland";
  services.displayManager.sddm.wayland.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  hardware.graphics.enable = true;

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
}

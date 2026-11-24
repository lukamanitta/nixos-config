{ pkgs, ... }:

{
  # Hyprland 0.55.4 leaves the seat's keyboard focus on a layer surface after
  # it releases keyboard interactivity, so a window loses typing until another
  # window is focused. Fixed upstream in 0.56.0 (PR #14953); patch until
  # nixpkgs ships it. See docs/WORKSTATION-TROUBLESHOOTING.md.
  nixpkgs.overlays = [
    (final: prev: {
      hyprland = prev.hyprland.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./patches/hyprland-focus-restore.patch ];
      });
    })
  ];

  programs.hyprland.enable = true;

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
      user = "greeter";
    };
  };

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

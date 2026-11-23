{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

# Creative/desktop applications for the workstation. Kept host-level because
# several of them need unfree packages and system integration (OpenCL, udev,
# OBS devices); the user-level pieces (Google Drive mount) live under
# modules/users/features.
let
  cfg = config.my.creative;
in
{
  options.my.creative.davinciResolve = lib.mkEnableOption ''
    DaVinci Resolve (unfree). Enable once the nixpkgs source fetch/RDNA4
    OpenCL path is known-good; it currently fails before the build starts.
  '';

  config = {
    nixpkgs.overlays = [
      inputs.affinity-nix.overlays.default
    ];

    # Narrow allow-list rather than global allowUnfree.
    nixpkgs.config.allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "affinity-v3"
        "affinity-extracted-sources"
        "davinci-resolve"
        "discord"
        "slack"
        "spotify"
      ];

    environment.systemPackages =
      with pkgs;
      [
        affinity-v3
        discord
        slack
        spotify
        vlc
      ]
      ++ lib.optional cfg.davinciResolve davinci-resolve;

    # PipeWire screen/audio capture is native in OBS 32. The virtual camera is
    # intentionally off until it is actually needed.
    programs.obs-studio.enable = true;
  };
}

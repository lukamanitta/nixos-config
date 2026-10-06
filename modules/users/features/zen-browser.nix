{ lib, inputs, ... }:

{
  # zen-browser is not in nixpkgs (checked 26.05 and unstable); the community
  # flake ships this Home Manager module (mkFirefoxModule-based).
  imports = [ inputs.zen-browser.homeModules.beta ];

  my.desktop.programs.browser = lib.mkDefault "zen-beta";

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
  };
}

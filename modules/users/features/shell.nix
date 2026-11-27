{ ... }:

{
  home.sessionVariables.EDITOR = "nvim";

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}

{ ... }:

{
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  xdg.configFile."gh/config.yml".enable = false;
}

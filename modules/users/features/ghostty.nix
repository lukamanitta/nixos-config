{ pkgs, ... }:

{
  home.packages = [ pkgs.ghostty ];

  xdg.configFile = {
    "ghostty/config".text = ''
      font-size = 12
      window-padding-x = 8
      window-padding-y = 8
      confirm-close-surface = false
    '';

    # Declare ghostty as the preferred terminal for xdg-terminal-exec; the
    # compositor only binds to the standard, never to ghostty directly.
    "xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\n";
  };
}

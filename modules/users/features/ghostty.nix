{
  config,
  pkgs,
  lib,
  ...
}:

# Ghostty is the terminal provider (role), and it is also where the chosen
# multiplexer auto-attaches. tmux/herdr contribute
# `my.desktop.programs.multiplexer`; this feature renders it.
let
  multiplexer = config.my.desktop.programs.multiplexer;
in
{
  my.desktop.programs.terminal = lib.mkDefault "ghostty";

  home.packages = [ pkgs.ghostty ];

  xdg.configFile = {
    "ghostty/config".text = ''
      theme = Luka
      font-size = 12
      window-padding-x = 8
      window-padding-y = 8
      confirm-close-surface = false
    ''
    + lib.optionalString (multiplexer != null) ''
      command = ${multiplexer}
    '';

    # Declare ghostty as the preferred terminal for xdg-terminal-exec; the
    # compositor only binds to the standard, never to ghostty directly.
    "xdg-terminals.list".text = "com.mitchellh.ghostty.desktop\n";
  };
}

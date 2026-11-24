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

      keybind = ctrl+shift+r=reload_config

      font-family = "Roboto Mono"
      font-size = 11.5
      font-style = "Regular"
      font-variation = wght=470
      font-variation-italic = wght=470
      font-variation-bold = wght=700
      adjust-font-baseline = 1
      adjust-underline-thickness = 1

      font-codepoint-map = U+E000-U+EFFF=Symbols Nerd Font
      adjust-icon-height = -30%
      adjust-cursor-thickness = 2

      adjust-cell-height = 25%
      window-padding-x = 6
      window-padding-y = 0

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

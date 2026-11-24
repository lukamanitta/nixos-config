{
  lib,
  inputs,
  pkgs,
  ...
}:

let
  zen = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system};

  # Zen applies userChrome.css at startup but never reloads it. The browser
  # resolves its application directory to the *unwrapped* package (the wrapper
  # only symlinks the files), so autoconfig has to live there: a pref file in
  # defaults/pref points at colourme.cfg, which watches
  # <profile>/chrome/userChrome.css and re-registers the sheet whenever
  # colourme rewrites it. The pref file is deliberately not named
  # autoconfig.js so the wrapper's own autoconfig preparation cannot collide
  # with it.
  unwrapped = zen.beta-unwrapped.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      _zen_app="$out/lib/zen-bin-${old.version}"
      chmod u+w "$_zen_app"
      chmod -R u+w "$_zen_app/defaults"
      install -Dm644 ${./zen/files/autoconfig.js} "$_zen_app/defaults/pref/00-colourme-autoconfig.js"
      install -Dm644 ${./zen/files/config.js} "$_zen_app/colourme.cfg"
    '';
  });
  patched = (import "${inputs.zen-browser}/wrap-zen.nix" pkgs.wrapFirefox) unwrapped {
    icon = "zen-browser";
  };
in
{
  # zen-browser is not in nixpkgs (checked 26.05 and unstable); the community
  # flake ships this Home Manager module (mkFirefoxModule-based).
  imports = [ inputs.zen-browser.homeModules.beta ];

  my.desktop.programs.browser = lib.mkDefault "zen-beta";

  programs.zen-browser = {
    enable = true;
    package = patched;
    setAsDefaultBrowser = true;
  };

  # Point the default profile's userChrome.css at the colourme runtime file and
  # install the live-reload module plus its chrome manifest. Zen generates the
  # profile directory name, so resolve it from profiles.ini rather than
  # hardcoding it.
  home.activation.linkZenUserChrome =
    lib.hm.dag.entryAfter [ "writeBoundary" "seedColourmeTheme" ]
      ''
        _zen_root="$HOME/.config/zen"
        _zen_ini="$_zen_root/profiles.ini"
        if [ -f "$_zen_ini" ]; then
          _zen_rel=$(${pkgs.gnused}/bin/sed -n 's/^Path=//p' "$_zen_ini" | ${pkgs.coreutils}/bin/head -n 1)
          if [ -n "$_zen_rel" ] && [ -d "$_zen_root/$_zen_rel" ]; then
            _zen_chrome="$_zen_root/$_zen_rel/chrome"
            run mkdir -p "$_zen_chrome/colourme"
            run ln -sfn "$HOME/.local/state/colourme/zen-userChrome.css" \
              "$_zen_chrome/userChrome.css"
            run ln -sfn ${./zen/files/colourme.sys.mjs} "$_zen_chrome/colourme/colourme.sys.mjs"
            run install -m644 ${./zen/files/chrome.manifest} "$_zen_chrome/colourme/chrome.manifest"
          fi
        fi
      '';
}

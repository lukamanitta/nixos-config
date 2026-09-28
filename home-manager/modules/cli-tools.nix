{ pkgs, ... }:

{
  home.packages = with pkgs; [
    zip
    unzip
    jq
    btop
  ];
}

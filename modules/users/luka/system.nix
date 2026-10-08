{ pkgs, ... }:

{
  programs.zsh.enable = true;

  users.users.luka = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" ];
    initialHashedPassword = "$6$a7aMZwefxETVWbsR$5Lyl2FY0RVBUabb/DuVz.ni51TmA7nIHRwHxPqMpMPwSR/cDIdSzagH1McOu8DZEZU5Xxw7F7FUsVXL0V0P4V1";
  };
}

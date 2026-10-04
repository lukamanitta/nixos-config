{ ... }:

{
  users.users.luka = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };
}

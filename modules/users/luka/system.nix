{ pkgs, ... }:

{
  programs.zsh.enable = true;

  users.users.luka = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];

    # Agent access from the workstation (`ssh luka-nixos-test`). Public key only.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0IIlFwV4Aql1wDAiOnQ/tEkL/9AMZ5MkZtpMdgjUZK agent@arch -> luka-nixos-test"
    ];

    initialHashedPassword = "$6$a7aMZwefxETVWbsR$5Lyl2FY0RVBUabb/DuVz.ni51TmA7nIHRwHxPqMpMPwSR/cDIdSzagH1McOu8DZEZU5Xxw7F7FUsVXL0V0P4V1";
  };
}

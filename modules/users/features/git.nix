{ ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Luka Manitta";
      user.email = "luka@lukamanitta.com";
      pull.rebase = true;
      # Work repos put git@github.com: URLs in .gitmodules, but this machine
      # authenticates git with gh over https. Rewrite so submodules use the
      # same credential helper.
      url."https://github.com/".insteadOf = "git@github.com:";
    };
  };
}

{ ... }:

{
  programs.git = {
    enable = true;
    # Per-repo shell wiring is personal; keep it out of the work repos.
    ignores = [
      ".direnv"
      ".envrc"
    ];
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

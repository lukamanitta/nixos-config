{ ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user.name = "Luka Manitta";
      user.email = "luka@lukamanitta.com";
      pull.rebase = true;
    };
  };
}

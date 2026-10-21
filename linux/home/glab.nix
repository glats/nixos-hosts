{ pkgs, ... }:

{
  home.packages = [ pkgs.glab ];

  programs.git.includes = [
    {
      contents.credential."https://gitlab.com".helper = [
        ""
        "!${pkgs.glab}/bin/glab auth git-credential"
      ];
    }
  ];
}

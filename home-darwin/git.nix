{ pkgs, primaryUser, ... }:
{
  # create a separate git config fragment for Falabella-managed repos
  home.file.".git-falabella".text = ''
    [user]
      name = ${toString primaryUser};
      email = ${toString primaryUser}@falabella.cl
    [user]
      signingkey = B658D64F6FDBCFD1EBA53509A1D4ECB0118566C8
    [commit]
      gpgsign = true
    [gpg]
      program = ${pkgs.gnupg}/bin/gpg
  '';

  programs.git = {
    enable = true;
    lfs.enable = true;

    ignores = [ "**/.DS_STORE" ];
    settings = {
      user = {
        name = primaryUser;
        email = "${primaryUser}@falabella.cl";
      };

      # include .git-falabella for repos under ~/Work/
      includeIf."gitdir:~/Work/**".path = "~/.git-falabella";

      github.user = primaryUser;
      init.defaultBranch = "main";
      core.editor = "nvim -u NONE";
      gpg.program = "${pkgs.gnupg}/bin/gpg";
    };

    signing = {
      key = "B658D64F6FDBCFD1EBA53509A1D4ECB0118566C8"; # the GPG key we generated
      signByDefault = true;
    };
  };
}

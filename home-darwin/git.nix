{ pkgs
, config
, primaryUser
, lib
, ...
}:

let
  identities = import ../shared/git-identity.nix;
in
{
  programs.git = {
    enable = true;
    lfs.enable = true;

    ignores = [ "**/.DS_STORE" ];
    settings = {
      user = {
        name = identities.jcuzmar.name;
        email = identities.jcuzmar.email;
      };

      github.user = primaryUser;
      init.defaultBranch = "main";
      core.editor = "nvim -u NONE";
      gpg.program = "${pkgs.gnupg}/bin/gpg";
    };

    # Sign work commits with jcuzmar key by default
    signing = {
      key = identities.jcuzmar.signingKey;
      signByDefault = true;
    };

    includes = [
      # Work repos also sign with jcuzmar key (same as default, explicit)
      {
        condition = "gitdir:~/Work/**";
        contents = {
          user.name = identities.jcuzmar.name;
          user.email = identities.jcuzmar.email;
          user.signingKey = identities.jcuzmar.signingKey;
          commit.gpgsign = true;
        };
      }
    ]
    # Personal repos sign with glats key if set
    ++ lib.optional (identities.glats.signingKey != "") {
      condition = "gitdir:~/Personal/**";
      contents = {
        user.name = identities.glats.name;
        user.email = identities.glats.email;
        user.signingKey = identities.glats.signingKey;
        commit.gpgsign = true;
      };
    };
  };
}

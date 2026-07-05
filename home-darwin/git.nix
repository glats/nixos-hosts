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

    signing = {
      key = builtins.readFile config.sops.secrets."github/gpg_key_fingerprint".path;
      signByDefault = true;
    };

    includes = [
      {
        condition = "gitdir:~/Work/**";
        contents = {
          user.name = identities.jcuzmar.name;
          user.email = identities.jcuzmar.email;
        };
      }
      {
        condition = "gitdir:~/Personal/**";
        contents = {
          user.name = identities.glats.name;
          user.email = identities.glats.email;
        };
      }
    ];
  };
}

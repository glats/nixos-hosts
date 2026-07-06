{ config, lib, pkgs, ... }:

let
  identities = import ../shared/git-identity.nix;
in
{
  programs.git = {
    enable = true;
    settings = {
      core.editor = "nvim -u NONE";
      core.pager = "delta";
      delta.enable = true;
      gpg.program = "${pkgs.gnupg}/bin/gpg";
      # lib.mkForce required on t14: omarchy-nix's HM module reads
      # `omarchy.email_address` and writes to user.email, which would
      # otherwise override this value with `glats@local`.
      user.name = lib.mkForce identities.glats.name;
      user.email = lib.mkForce identities.glats.email;
    };

    # Explicitly set signing format to silence home-manager warning (legacy default)
    # If glats GPG key is set, also sign personal commits with it
    signing = { format = "openpgp"; }
      // lib.optionalAttrs (identities.glats.signingKey != "") {
        key = identities.glats.signingKey;
        signByDefault = true;
      };

    includes = [
      # Work repos always sign with jcuzmar key
      {
        condition = "gitdir:~/Work/**";
        contents = {
          user.name = identities.jcuzmar.name;
          user.email = identities.jcuzmar.email;
          user.signingKey = identities.jcuzmar.signingKey;
          commit.gpgsign = true;
        };
      }
    ];
  };
}

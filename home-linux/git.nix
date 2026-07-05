{ config, lib, ... }:

let
  identities = import ../shared/git-identity.nix;
in
{
  programs.git = {
    enable = true;
    # Explicitly set signing format to silence home-manager warning (legacy default)
    signing.format = "openpgp";
    settings = {
      core.editor = "nvim -u NONE";
      core.pager = "delta";
      delta.enable = true;
      # lib.mkForce required on t14: omarchy-nix's HM module reads
      # `omarchy.email_address` and writes to user.email, which would
      # otherwise override this value with `glats@local`.
      user.name = lib.mkForce identities.glats.name;
      user.email = lib.mkForce identities.glats.email;
    };
    includes = [
      {
        condition = "gitdir:~/Work/**";
        contents = {
          user.name = identities.jcuzmar.name;
          user.email = identities.jcuzmar.email;
        };
      }
    ];
  };
}

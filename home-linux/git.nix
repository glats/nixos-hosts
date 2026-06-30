{ config, lib, ... }:

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
      user.name = lib.mkForce "Juan Cuzmar";
      user.email = lib.mkForce "jcuzmar@protonmail.com";
    };
  };
}

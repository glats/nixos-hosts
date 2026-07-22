{ config, lib, pkgs, ... }:

let
  identities = import ../../shared/git-identity.nix;
in
{
  programs.git = {
    enable = true;
    settings = {
      core.editor = "nvim -u NONE";
      core.pager = "delta";
      core.hooksPath = "~/.config/git/hooks";
      delta.enable = true;
      gpg.program = "${pkgs.gnupg}/bin/gpg";
      # Placeholder -- overridden by identity-personal include file written
      # at activation from sops decrypted secrets. lib.mkForce is required
      # on t14 where omarchy-nix writes glats@local.
      user.name = lib.mkForce "placeholder";
      user.email = lib.mkForce "placeholder";
    };

    # Explicitly set signing format to silence home-manager warning (legacy default)
    # If personal GPG key is set, also sign personal commits with it
    signing = { format = "openpgp"; }
      // lib.optionalAttrs (identities.personal.signingKey != "") {
      key = identities.personal.signingKey;
      signByDefault = true;
    };

    includes = [
      # Default identity from activation-written file
      { path = "~/.config/git/identity-personal"; }
      # Work identity from activation-written file
      {
        condition = "gitdir:~/Work/**";
        path = "~/.config/git/identity-work";
      }
      # Work signing config (GPG keys are public, stay in Nix)
      {
        condition = "gitdir:~/Work/**";
        contents = {
          user.signingKey = identities.work.signingKey;
          commit.gpgsign = true;
        };
      }
    ];
  };

  # Write git identity include files from sops-decrypted secrets at activation time.
  # Runs after writeBoundary (same timing as gpg.nix key import).
  # Gracefully skips if sops secrets are not yet available.
  home.activation.writeGitIdentity = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _write_identity() {
      _mode="$1"
      _name_file="$2"
      _email_file="$3"
      _out_file="$HOME/.config/git/identity-$_mode"

      if [ ! -f "$_name_file" ] || [ ! -f "$_email_file" ]; then
        return 0  # skip silently if sops secrets not available
      fi

      mkdir -p "$(dirname "$_out_file")"
      _name="$(cat "$_name_file")"
      _email="$(cat "$_email_file")"
      printf "[user]\n    name = %s\n    email = %s\n" "$_name" "$_email" > "$_out_file"
    }
    _write_identity "personal" \
      "${config.sops.secrets."identities/personal_name".path}" \
      "${config.sops.secrets."identities/personal_email".path}"
    _write_identity "work" \
      "${config.sops.secrets."identities/work_name".path}" \
      "${config.sops.secrets."identities/work_email".path}"
  '';

  # Strip AI co-author trailers from commits.
  # Claude Code has a known bug where attribution.commit="" doesn't reliably
  # prevent Co-Authored-By trailers (anthropics/claude-code#45137, #4287).
  # This commit-msg hook is the only 100% reliable fix.
  home.file.".config/git/hooks/commit-msg" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      # Strip AI-generated Co-Authored-By trailers from commit messages.
      # Matches: "Co-Authored-By: Claude <...>" and variants.
      ${pkgs.gnused}/bin/sed -i '/^Co-Authored-By:.*<noreply@anthropic\.com>/d' "$1"
    '';
  };
}

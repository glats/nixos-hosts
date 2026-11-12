{
  config,
  lib,
  pkgs,
  ...
}:

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
      user.name = lib.mkForce "placeholder";
      user.email = lib.mkForce "placeholder";
    };

    signing = {
      format = "openpgp";
      key = identities.signingKeyFallback;
      signByDefault = true;
    };

    includes = [
      { path = "~/.config/git/identity-personal"; }
      { path = "~/.config/git/signing-personal"; }
      { contents.credential = identities.mkCredential pkgs.gh "glats"; }
      {
        condition = "gitdir:~/Work/**";
        path = "~/.config/git/identity-work";
      }
      {
        condition = "gitdir:~/Work/**";
        contents = {
          user.signingKey = identities.signingKeyFallback;
          commit.gpgsign = true;
          credential = identities.mkCredentialFromFile pkgs.gh config.sops.secrets."github/work_account".path;
        };
      }
      {
        condition = "gitdir:~/Work/**";
        path = "~/.config/git/signing-work";
      }
    ];
  };

  home.activation.writeGitIdentity = lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix" ] ''
    _write_identity() {
      _mode="$1"
      _name_file="$2"
      _email_file="$3"
      _out_file="$HOME/.config/git/identity-$_mode"

      # sops-nix installs secrets asynchronously (systemd user service); wait
      # briefly so the first activation does not silently skip the identity.
      for ((i = 0; i < 50; i++)); do
        { [ -f "$_name_file" ] && [ -f "$_email_file" ]; } && break
        sleep 0.2
      done

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
    ${identities.mkSigningIdentity {
      gpgProgram = "${pkgs.gnupg}/bin/gpg";
      guardProgram = "${pkgs.coreutils}/bin/false";
      entries = [
        {
          scope = "personal";
          fingerprint = config.sops.secrets."github/personal_gpg_fingerprint".path;
        }
        {
          scope = "work";
          fingerprint = config.sops.secrets."github/work_gpg_fingerprint".path;
        }
      ];
    }}
  '';

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

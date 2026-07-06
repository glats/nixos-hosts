{ config
, pkgs
, lib
, ...
}:

let
  # Activation script that validates GitHub tokens after sops deploys them.
  # Runs on every nixos-build switch to catch expired tokens early.
  tokenCheckScript = pkgs.writeShellScript "github-token-check" ''
    set -euo pipefail

    check_token() {
      local label="$1"
      local pat_file="$2"

      if [ ! -f "$pat_file" ]; then
        return 0  # Not configured on this host — skip silently
      fi

      local token
      token="$(cat "$pat_file" 2>/dev/null)" || return 0

      # Test via gh auth status
      if GH_TOKEN="$token" ${pkgs.gh}/bin/gh auth status --active \
        --hostname github.com >/dev/null 2>&1; then
        echo "  $label: token valid"
      else
        echo "WARNING: $label GitHub token at $pat_file is expired or invalid!" >&2
        echo "  Create a new PAT at: https://github.com/settings/tokens" >&2
        echo "  Then: sops secrets/shared/passwords.yaml" >&2
        echo "  Then: nixos-build switch" >&2
      fi
    }

    echo "Checking GitHub tokens..."
    check_token "glats"  "${config.sops.secrets."github/pat".path}"
    check_token "jcuzmar" "${config.sops.secrets."github/pat_jcuzmar".path}"
  '';
in
{
  config = lib.mkIf (config.sops.secrets ? "github/pat") {
    system.activationScripts.githubTokenCheck = lib.stringAfter [ "setupSecrets" ]
      ''${tokenCheckScript}'';
  };
}

#!/usr/bin/env bash
# Add github/pat secret to sops secrets.yaml

set -euo pipefail

GH_TOKEN="${1:-$(gh auth token 2>/dev/null || true)}"

if [ -z "$GH_TOKEN" ]; then
    echo "Error: No GitHub token provided and gh auth token failed"
    exit 1
fi

echo "Adding github/pat secret to sops..."

export SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt
cd /etc/nixos

# Decrypt
sops -d secrets/secrets.yaml > /tmp/secrets_plain.yaml

# Add github section before opencode
awk -v token="$GH_TOKEN" '
/^opencode:/ && !added {
    print "github:"
    print "    pat:", token
    print ""
    added = 1
}
{ print }
' /tmp/secrets_plain.yaml > /tmp/secrets_new.yaml

# Re-encrypt
cat /tmp/secrets_new.yaml | sops -e /dev/stdin > secrets/secrets.yaml

# Cleanup
rm /tmp/secrets_plain.yaml /tmp/secrets_new.yaml

echo "✓ Secret github/pat added successfully!"
echo "  Run: cd /etc/nixos && nixos-build switch"

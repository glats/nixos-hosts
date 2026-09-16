#!/usr/bin/env bash
# Extract the Netskope/Falabella MITM root CA from Apple SecTrust and save
# it to certs/netskope-falabella.crt for the Nix corporate CA bundle.
#
# Run this once after cloning, and whenever the corporate cert is rotated.
# The .crt file is gitignored — it never gets committed to the repo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_FILE="$REPO_ROOT/certs/netskope-falabella.crt"

mkdir -p "$REPO_ROOT/certs"

echo "Extracting Netskope root CA from Apple SecTrust..."
/usr/bin/security find-certificate -a -c "certadmin" -p /Library/Keychains/System.keychain > "$OUT_FILE"

echo "Saved to $OUT_FILE"
echo "Subject: $(openssl x509 -noout -subject < "$OUT_FILE")"
echo "Expires: $(openssl x509 -noout -enddate < "$OUT_FILE")"

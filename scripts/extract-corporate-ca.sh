#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_FILE="$REPO_ROOT/certs/netskope-falabella.crt"

mkdir -p "$REPO_ROOT/certs"

echo "Extracting Netskope root CA from Apple SecTrust..."
/usr/bin/security find-certificate -a -c "certadmin" -p /Library/Keychains/System.keychain >"$OUT_FILE"

echo "Saved to $OUT_FILE"
echo "Subject: $(openssl x509 -noout -subject <"$OUT_FILE")"
echo "Expires: $(openssl x509 -noout -enddate <"$OUT_FILE")"

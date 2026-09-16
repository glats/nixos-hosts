#!/usr/bin/env bash
# extract-corporate-ca.sh — Extract the Netskope/Falabella corporate CA certificate
#
# Usage: docs/scripts/extract-corporate-ca.sh > certs/netskope-falabella.crt
#
# Requires: openssl, network access to a HTTPS site through the corporate proxy.
# The script connects to google.com (port 443) and extracts the second
# certificate in the chain — the intermediate CA that signs the leaf cert.
# This is the Netskope MITM CA used by Falabella's corporate network.

set -euo pipefail

# Connect through the corporate proxy and dump the certificate chain.
# -showcerts outputs all certificates in the chain as PEM blocks.
CHAIN=$(openssl s_client -connect www.google.com:443 -showcerts 2>/dev/null)

# Extract the second PEM block (index 2, the intermediate CA).
# awk state machine: count BEGIN/END markers, print only the second cert.
echo "$CHAIN" | awk '
/BEGIN CERTIFICATE/ { n++ }
n == 2 { print }
/END CERTIFICATE/ && n == 2 { exit }
'

#!/usr/bin/env bash

set -euo pipefail

CHAIN=$(openssl s_client -connect www.google.com:443 -showcerts 2>/dev/null)

echo "$CHAIN" | awk '
/BEGIN CERTIFICATE/ { n++ }
n == 2 { print }
/END CERTIFICATE/ && n == 2 { exit }
'

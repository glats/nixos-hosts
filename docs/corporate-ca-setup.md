# Corporate CA Setup — New Machine

Fabella's corporate network uses a Netskope MITM proxy that intercepts all
HTTPS traffic. Nix-built programs (curl, git, nvim-treesitter) don't trust
the proxy's CA by default because they use the Nix-bundled Mozilla CA store
rather than macOS Keychain.

This doc covers extracting the corporate CA and making it available to Nix
programs on a new macOS machine.

## Quick Reference

```bash
# 1. Extract corporate CA from the proxy
docs/scripts/extract-corporate-ca.sh > certs/netskope-falabella.crt

# 2. The CA is already wired in hosts/macm5/default.nix via corporateCaBundle
#    Just deploy:
nixos-build
```

## How It Works

`hosts/macm5/default.nix` defines a `corporateCaBundle` derivation that
combines the Mozilla CA bundle (`pkgs.cacert`) with the Netskope corporate
CA certificate into a single file. The `NIX_SSL_CERT_FILE` environment
variable points to this combined bundle.

```
Mozilla CA (121 certs) + Netskope CA (1 cert) → 122-cert bundle
                                                    ↓
                              NIX_SSL_CERT_FILE → /nix/store/.../ca-bundle.crt
```

This overrides OpenSSL's default CA path on macOS (`/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt`),
ensuring all Nix-built programs trust both public and corporate CAs.

### Why Not `security.pki.certificateFiles`?

nix-darwin's `security.pki.certificateFiles` manages `/etc/ssl/certs/ca-certificates.crt`.
Determinate Nix also owns this path via its own symlink farm. The two conflict —
nix-darwin's activation script silently skips it (outputs `[ssl/certs/ca-certificates.crt]=''`).
`NIX_SSL_CERT_FILE` is the recommended override for MITM proxy scenarios.

## Step-by-Step

### 1. Extract the Corporate CA

On a machine connected to the corporate network, run:

```bash
# Interactive — prompts for sudo password for network diagnostics
docs/scripts/extract-corporate-ca.sh
```

Or manually with openssl:

```bash
openssl s_client -connect www.google.com:443 -showcerts 2>/dev/null | \
  awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{ print }' | \
  awk 'BEGIN{n=0} /BEGIN CERTIFICATE/{n++} n==2{print}' \
  > certs/netskope-falabella.crt
```

The script extracts the **second** certificate in the chain (the intermediate
CA that signs the leaf certificate). This is the Netskope/Falabella MITM CA.

Verify the extracted cert:

```bash
openssl x509 -in certs/netskope-falabella.crt -noout -subject -issuer
# Expected:
#   subject=CN = ca.grupofalabella.goskope.com
#   issuer=CN = certadmin, O = Netskope Inc.
```

### 2. Verify the Combined Bundle

Before deploying, you can test locally:

```bash
# Build the combined bundle via Nix eval
nix eval --raw .#darwinConfigurations.macm5.config.environment.variables.NIX_SSL_CERT_FILE

# Or manually combine for a quick test
cat $(nix-build -A cacert '<nixpkgs>')/etc/ssl/certs/ca-bundle.crt \
    certs/netskope-falabella.crt > /tmp/combined-ca.crt

# Test TLS verification
curl --cacert /tmp/combined-ca.crt -s -o /dev/null -w "%{http_code}" https://github.com
# Expected: 200
```

### 3. Deploy

```bash
nixos-build
```

This runs `darwin-rebuild switch` and applies the `NIX_SSL_CERT_FILE`
variable system-wide. After deployment:

```bash
# Verify the variable is set
echo $NIX_SSL_CERT_FILE
# Expected: /nix/store/.../corporate-ca-bundle/etc/ssl/certs/ca-bundle.crt

# Test from a new shell
curl -s -o /dev/null -w "%{http_code}" https://github.com
# Expected: 200
```

### 4. Verify Neovim

Open nvim and check that treesitter parsers download without SSL errors:

```bash
nvim --headless -c 'TSInstallSync lua' -c 'q' 2>&1 | head -5
```

If you see "downloading" messages without SSL errors, the fix is working.

## Adding a New Host

If the new machine needs a different host entry in `flake.nix`:

1. Create `hosts/<hostname>/default.nix` — copy `hosts/macm5/default.nix` as
   a starting point
2. Add the host to `flake.nix` under `darwinConfigurations`
3. The `corporateCaBundle` + `NIX_SSL_CERT_FILE` block should be copied to
   the new host's `default.nix`
4. Run `nixos-build` and select the new host configuration

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `SSL: certificate verification failed` in curl/git | Re-extract the CA cert; corporate certs rotate every ~90 days |
| `NIX_SSL_CERT_FILE` is empty after deploy | Run `nixos-build` again; the variable must be in `environment.variables` |
| Neovim parsers fail to download | Check `:checkhealth` output; ensure nvim was launched from a shell with `NIX_SSL_CERT_FILE` set |
| `nix flake check` fails on unrelated host | Pre-existing failure; if your changes don't touch that host, note it and proceed |

## Certificate Rotation

The Netskope proxy rotates its CA certificate periodically (~90 days). When
this happens:

1. Extract the new CA on any corporate-connected machine
2. Replace `certs/netskope-falabella.crt` with the new cert
3. Commit and deploy (`nixos-build`)

The file is committed to the repo because it's a configuration artifact
(public CA cert), not a secret.

## Files

- `certs/netskope-falabella.crt` — The corporate MITM CA certificate
- `hosts/macm5/default.nix` — Contains `corporateCaBundle` + `NIX_SSL_CERT_FILE`
- `docs/scripts/extract-corporate-ca.sh` — Automated extraction script

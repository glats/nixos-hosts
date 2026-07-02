# Review Checkpoint: problema-sops-mact2

## Verdict: APPROVED

Rework level: none
Iteration decision needed: No

## Guard Lines

### CONFIG: `.sops.yaml` rule for `secrets/shared/.+`

- [x] Line 39: `- *host_mact2` added after `- *host_t14`
- [x] YAML anchor `&host_mact2` already defined at line 6
- [x] `secrets/shared/.+` now has all 5 keys: admin_glats, host_rog, host_thinkcentre, host_t14, host_mact2
- [x] `nix flake check --no-build` passes

### SECURITY: Re-encryption of `passwords.yaml`

- [x] `sops updatekeys` completed successfully
- [x] Recipient count: 5 (was 4)
- [x] No plaintext modified -- only sops metadata changed
- [x] New mact2 recipient key matches `&host_mact2` anchor (`age1ngeetv...`)

### DEPLOYMENT: mact2

- [x] Commit pushed to remote (167a46b)
- [x] Repo updated on mact2 to 167a46b
- [x] `home-manager switch` on mact2 succeeded with `Activating sops-nix`
- [x] `github/pat` decrypted (40 bytes at `~/.config/sops-nix/secrets/github/pat`)
- [x] `github/token` decrypted (40 bytes at `~/.config/sops-nix/secrets/github/token`)
- [x] All `opencode/*` secrets decrypted (11 files)
- [x] `github-mcp-server-wrapped --help` executed successfully (proves wrapper reads token and launches server)

## Summary

| File | Change | Status |
|------|--------|--------|
| `.sops.yaml` | +1 line: `- *host_mact2` in shared rule | Verified |
| `secrets/shared/passwords.yaml` | Re-encrypted with 5 recipients (was 4) | Verified |
| mact2 deployment | SSH + home-manager switch | Verified |
| MCP server | github-mcp-server-wrapped works | Verified |

## Rollback

To revert: remove line 39 from `.sops.yaml`, then run `sops updatekeys secrets/shared/passwords.yaml` on any Linux host.

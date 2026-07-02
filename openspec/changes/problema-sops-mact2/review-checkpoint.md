# Review Checkpoint: problema-sops-mact2

## Guard Lines

### CONFIG: `.sops.yaml` rule for `secrets/shared/.+`

- [x] Line 39: `- *host_mact2` added after `- *host_t14`
- [x] YAML anchor `&host_mact2` already defined at line 6
- [x] `secrets/shared/.+` now has all 5 keys: admin_glats, host_rog, host_thinkcentre, host_t14, host_mact2
- [x] `nix flake check --no-build` passes (proves no structural YAML error)

### SECURITY: Re-encryption of `passwords.yaml`

- [x] `sops updatekeys` completed successfully
- [x] Recipient count: 5 (was 4)
- [x] No plaintext modified -- only sops metadata changed in git diff
- [x] New mact2 recipient key matches `&host_mact2` anchor (`age1ngeetv...`)

### DEPLOYMENT: Pending user steps

- [ ] Commit pushed to remote
- [ ] `darwin-rebuild switch` on mact2 succeeds
- [ ] No sops decryption errors in darwin-rebuild output
- [ ] GitHub MCP server on mact2 resolves `github/pat` correctly

## Summary

| File | Change | Status |
|------|--------|--------|
| `.sops.yaml` | +1 line: `- *host_mact2` in shared rule | Verified |
| `secrets/shared/passwords.yaml` | Re-encrypted with 5 recipients (was 4) | Verified |
| mact2 deployment | SSH + darwin-rebuild switch | Pending user |

## Rollback

To revert: remove line 39 from `.sops.yaml`, then run `sops updatekeys secrets/shared/passwords.yaml` on any Linux host.

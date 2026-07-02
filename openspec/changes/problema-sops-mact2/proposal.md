# Proposal: SopS Decrypt Failure on mact2

## Intent

Fix sops-nix on mact2 by granting the mact2 AGE key access to shared secrets, so all hosts uniformly decrypt `secrets/shared/passwords.yaml`.

## Scope

- **In scope**: `.sops.yaml` creation rule for `secrets/shared/.+`, re-encryption of `secrets/shared/passwords.yaml`.
- **Out of scope**: Any other secret file, any Nix module logic change, key rotation.

## Capabilities

1. `secrets/shared/.+` rule in `.sops.yaml` includes `host_mact2`.
2. `secrets/shared/passwords.yaml` is re-encrypted with all 5 recipient keys.
3. `home-manager switch` on mact2 decrypts all shared secrets without error.
4. `github-mcp-server-wrapped` on mact2 resolves `config.sops.secrets."github/token".path` successfully (previously blocked by the all-or-nothing failure of passwords.yaml).

## Approach

**Design: Uniformity over isolation.** All hosts share the same sops keys and secrets. The fix adds mact2 to the encryption pool for `secrets/shared/.+` rather than moving secrets out of shared scope.

### Changes

| File | Action | Detail |
|------|--------|--------|
| `.sops.yaml` lines 32-38 | Edit | Add `- *host_mact2` to the `secrets/shared/.+` rule |
| `secrets/shared/passwords.yaml` | Re-encrypt | Run `sops updatekeys secrets/shared/passwords.yaml` on a Linux host (rog, thinkcentre, or t14) that already holds a valid key — this adds the mact2 AGE recipient without changing plaintext |

### Rationale

- `shared/sops.nix` declares `sops.secrets."github/pat"` from `passwords.yaml` and is imported by BOTH Linux (`home-linux/shared-modules.nix`) and Darwin (`home-darwin/sops.nix`). There is no platform guard.
- `modules/base/sops.nix` (NixOS-level) also declares `github/pat` from the same file.
- When one sops file fails decryption, sops-nix fails **entirely** — even decryptable secrets like `github/token` from `atlassian.yaml` are blocked.
- The mact2 AGE key (`age1ngeetv5mnt8ax30tmm6799qs2779905v0jafpywuydrvw2sz7yds7rlp5z`) is already defined as `&host_mact2` in `.sops.yaml` line 6 and used in other rules (opencode.yaml, atlassian.yaml) — it was simply omitted from `secrets/shared/.+`.

## Affected Areas

- `home-manager switch` on mact2 (currently broken for all sops secrets)
- `github-mcp-server-wrapped` on mact2 (dependent on `github/token`)
- Any future shared secret created under `secrets/shared/` (the updated rule ensures mact2 is always included)

## Risks

- **Low**: `.sops.yaml` change is a one-line edit. Re-encryption preserves existing plaintext; only metadata (recipient list) changes.
- **Mitigation**: The user runs `sops updatekeys` on a machine that already decrypts the file. If executed elsewhere, the command will fail safely.
- **Rollback**: Revert the `.sops.yaml` line and re-run `sops updatekeys` without `host_mact2`.

## Rollback Plan

1. Remove `- *host_mact2` from the `secrets/shared/.+` rule in `.sops.yaml`.
2. Run `sops updatekeys secrets/shared/passwords.yaml` on any Linux host to strip the mact2 key.

## Dependencies

- Requires `sops` CLI on a Linux host (rog, thinkcentre, or t14) to run `sops updatekeys`.
- Requires the user's AGE identity on that host to decrypt the current file.

## Success Criteria

1. `sops updatekeys secrets/shared/passwords.yaml` completes and the file now shows 5 recipient blocks in its `sops.age` metadata.
2. `home-manager switch` on mact2 completes with all secrets decrypted.
3. `cat $(readlink -f result/etc/github/token)` or equivalent on mact2 outputs a valid token.
4. `nix flake check --no-build` passes after the `.sops.yaml` edit.

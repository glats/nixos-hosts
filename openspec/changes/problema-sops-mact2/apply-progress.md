# Apply Progress: problema-sops-mact2

## Phase 1: Edit `.sops.yaml` [DONE]

Added `- *host_mact2` to the `secrets/shared/.+` creation rule at line 39 of `.sops.yaml`.

```diff
           - *host_t14
+          - *host_mact2
```

Validated via `nix flake check --no-build` -- all checks passed (NixOS + darwin configurations evaluated cleanly).

## Phase 2: Re-encrypt `secrets/shared/passwords.yaml` [DONE]

Ran `sops updatekeys secrets/shared/passwords.yaml` on rog (Linux host with valid AGE key). The command:

1. Confirmed the existing 4 recipients (admin_glats, host_rog, host_thinkcentre, host_t14)
2. Added `age1ngeetv5mnt8ax30tmm6799qs2779905v0jafpywuydrvw2sz7yds7rlp5z` (host_mact2)
3. Re-encrypted the file -- now has 5 recipient blocks

Verified with `yq '.sops.age | length' secrets/shared/passwords.yaml` -> `5`

Git diff confirms only sops metadata changed; plaintext (`github.pat`) is unmodified.

## Phase 3: Nix flake check [DONE]

```
nix flake check --no-build
```
All checks passed including all NixOS and darwin configurations.

## Phase 4: Deploy to mact2 [PENDING]

Manual steps required:

1. Push the commit to the remote:
   ```bash
   git push
   ```

2. SSH into mact2 and update:
   ```bash
   ssh mact2.local
   cd /etc/nixos
   git pull
   nix flake lock --update-input nixos-hosts
   darwin-rebuild switch --flake .#jcuzmar
   ```

3. Verify no sops decryption errors in the rebuild output.

4. Verify GitHub MCP server starts cleanly.

## Phase 5: Commit [DONE]

Commit: see review-checkpoint.md for commit details.

## Manual Steps for User

1. **Push** the commit to remote (`git push`)
2. **Deploy** to mact2 via SSH (commands above)
3. **Verify** GitHub MCP server on mact2 starts without errors

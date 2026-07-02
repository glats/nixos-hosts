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

## Phase 4: Deploy to mact2 [PARTIAL]

### Commit pushed to remote [DONE]

Pushed as commit `167a46b` to `origin/master`.

### mact2 repo updated [DONE]

```bash
ssh mact2.local "cd /Users/jcuzmar/Work/nixos-hosts && git fetch origin && git reset --hard origin/master"
```
mact2 is now at commit `167a46b`.

### darwin-rebuild switch [PENDING]

`sudo darwin-rebuild switch` requires an interactive TTY for password input. SSH non-interactive sudo is not available.

Run interactively on mact2:
```bash
ssh mact2.local
cd /Users/jcuzmar/Work/nixos-hosts
sudo darwin-rebuild switch --flake .#jcuzmar
```

Expected outcome: sops-nix decrypts `secrets/shared/passwords.yaml` without error (5 recipients now include mact2).

### Post-deploy verification [PENDING]

After `darwin-rebuild switch` completes:

1. Verify no `error: sops` or `failed to decrypt` lines in the output
2. Verify GitHub token exists at the sops-nix resolved path
3. Verify GitHub MCP server (`github-mcp-server-wrapped`) starts correctly

## Phase 5: Commit [DONE]

```
167a46b fix(sops): add host_mact2 to secrets/shared/.+ rule
```

Files committed:
- `.sops.yaml` (+1 line: `- *host_mact2` in shared rule)
- `secrets/shared/passwords.yaml` (re-encrypted with 5 recipients)
- `openspec/changes/problema-sops-mact2/` (proposal, tasks, apply-progress, review-checkpoint)

## Manual Steps for User

1. SSH into mact2 interactively: `ssh mact2.local`
2. Run: `cd /Users/jcuzmar/Work/nixos-hosts && sudo darwin-rebuild switch --flake .#jcuzmar`
3. Verify no sops decryption errors in the output
4. Verify GitHub MCP server starts cleanly

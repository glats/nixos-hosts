# Tasks: problema-sops-mact2

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1 (one YAML line addition) |
| Effective reviewable diff | 1 line |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr-default |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: single
400-line budget risk: Low

## Phase 1: Edit `.sops.yaml`

Add `host_mact2` to the `secrets/shared/.+` creation rule.

- [ ] 1.1 Insert `- *host_mact2` after line 37 (after `- *host_t14`) in the `secrets/shared/.+` block of `.sops.yaml`

  Expected diff:
  ```diff
     - path_regex: secrets/shared/.+
       key_groups:
         - age:
             - *admin_glats
             - *host_rog
             - *host_thinkcentre
             - *host_t14
  +          - *host_mact2
  ```

- [ ] 1.2 Run `nix flake check --no-build` to validate the YAML parsed correctly (no structural error)

## Phase 2: Re-encrypt `secrets/shared/passwords.yaml`

This must run on a Linux host (rog, thinkcentre, or t14) that already holds an AGE key capable of decrypting the file.

- [ ] 2.1 Confirm the file currently has 4 recipient blocks:

  ```bash
  nix shell nixpkgs#sops -c sops --decrypt secrets/shared/passwords.yaml > /dev/null 2>&1 && echo "DECRYPT OK" || echo "DECRYPT FAIL"
  ```

- [ ] 2.2 Run `sops updatekeys` to add the mact2 recipient:

  ```bash
  nix shell nixpkgs#sops -c sops updatekeys secrets/shared/passwords.yaml
  ```

  Verify the command exits 0. On success, `sops` re-writes the file with 5 recipient blocks in its `sops.age` metadata.

- [ ] 2.3 Verify recipients increased:

  ```bash
  nix shell nixpkgs#sops -c sops --decrypt secrets/shared/passwords.yaml > /dev/null 2>&1 && echo "STILL DECRYPT OK"
  nix shell nixpkgs#yq-go -c -- -r '.sops.age | length' secrets/shared/passwords.yaml
  ```

  Expected: `5` (was `4`)

- [ ] 2.4 Git-diff the file to confirm only `sops` metadata changed (no plaintext was modified):

  ```bash
  git diff secrets/shared/passwords.yaml
  ```

  Expected output: only `sops`-prefixed metadata lines changed. Zero plaintext changes.

## Phase 3: Nix flake check

- [ ] 3.1 `nix flake check --no-build` (must exit 0)

## Phase 4: Deploy to mact2

- [ ] 4.1 SSH into mact2 and update the flake lock + switch:

  ```bash
  ssh mact2 "cd /etc/nixos && nix flake lock --update-input nixos-hosts && darwin-rebuild switch --flake .#jcuzmar"
  ```

  Alternative using remote builder from a Linux host:

  ```bash
  nixos-build switch --target mact2
  ```

- [ ] 4.2 Verify no sops decryption errors in the rebuild output — look for `error: sops` or `failed to decrypt` lines. If clean, the fix is live.

## Phase 5: Verification (per spec success criteria)

- [ ] V.1 GIVEN `sops updatekeys` completes, WHEN `yq '.sops.age | length' secrets/shared/passwords.yaml` run, THEN result is `5`
- [ ] V.2 GIVEN `home-manager switch` on mact2, WHEN observed for sops errors, THEN zero decryption failures
- [ ] V.3 GIVEN the mact2 deployment, WHEN `github-mcp-server-wrapped` starts, THEN `config.sops.secrets."github/pat".path` resolves without error
- [ ] V.4 GIVEN `.sops.yaml` change merged, WHEN a new secret is added under `secrets/shared/`, THEN mact2 is automatically included as a recipient

## Phase 6: Commit

- [ ] 6.1 Stage and commit:

  ```bash
  git add .sops.yaml secrets/shared/passwords.yaml
  git commit -m "fix(sops): add host_mact2 to secrets/shared/.+ rule
  ...
  mact2 was missing from the secrets/shared/.+ creation rule in .sops.yaml,
  causing sops-nix to fail decrypting passwords.yaml on darwin.
  Re-encrypted passwords.yaml with all 5 recipient keys (admin_glats +
  4 hosts: rog, thinkcentre, t14, mact2)."
  ```

- [ ] 6.2 `git diff --stat main` — expect: 2 files changed, ~1 insertion YAML + sops metadata diff in passwords.yaml

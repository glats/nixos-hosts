# Tasks: GitHub auth via sops-nix for Linux hosts

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | +9 / -7 (≈ 16 net) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | 2 commits on main |
| Delivery strategy | direct-commits-on-main |
| Chain strategy | n/a |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: n/a
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Delivery | Notes |
|------|------|----------|-------|
| 1 | Auth + identity | commit 1 | `shared/sops.nix` + `home-linux/shell.nix` + `home-linux/git.nix`; additive; reaches all 3 hosts via existing shared-modules / omarchy.nix wiring |
| 2 | Cleanup | commit 2 | `hosts/rog/secrets.nix` — delete dead `git-credentials` block; revertable |

## Phase 1: HM sops + GH_TOKEN export (foundation)

- [x] 1.1 `shared/sops.nix` — append after line 44: `sops.secrets."github/pat" = { sopsFile = ../secrets/shared/passwords.yaml; mode = "0400"; };` (4 lines). Spec: `GH_TOKEN` + `gh CLI Authenticated`.
- [x] 1.2 `home-linux/shell.nix` — append inside `programs.zsh.initContent` (lib.mkAfter, before `''` on line 84): `if [ -f "${config.sops.secrets."github/pat".path}" ]; then export GH_TOKEN="$(cat ${config.sops.secrets."github/pat".path})"; fi` (3 lines). Spec: `GH_TOKEN` + `gracefully handles missing secret` scenario.

## Phase 2: Git identity + cleanup (application)

- [x] 2.1 `home-linux/git.nix` — add `user.name = "Redacted Name";` and `user.email = "personal@example.com";` inside `settings = { ... }` (2 lines, after line 11). Spec: `Git Identity on Linux Hosts`. **Note: implemented with `lib.mkForce` to override omarchy-nix's `email_address` -> `user.email` mapping on t14.**
- [x] 2.2 `hosts/rog/secrets.nix` — delete lines 49-55 (`sops.secrets."git-credentials"` block + comment). Spec: `Clean Up Unused Secret`.

## Phase 3: Verification

- [x] 3.1 `nix flake check --no-build` — passes for `rog`, `thinkcentre`, `t14` (NOT `mact2`).
- [x] 3.2 `format-nix` — clean.
- [x] 3.3 `rg 'git-credentials' --include='*.nix'` — no matches.
- [x] 3.4 `rg 'GH_TOKEN' --include='*.nix'` — only in `home-linux/shell.nix`.
- [ ] 3.5 After `nixos-build switch` on one host: `git config user.name` → `Redacted Name`; `echo $GH_TOKEN` → non-empty `gho_*`; `gh auth status` → exit 0. (deferred to verify phase — requires real host switch)

## Commit Plan (direct-commits-on-main)

| # | Type | Files | Message |
|---|------|-------|---------|
| 1 | feat | sops.nix + shell.nix + git.nix | `feat(gh-auth): wire github pat via sops for linux hosts` |
| 2 | chore | rog/secrets.nix | `chore(rog): remove unused git-credentials sops declaration` |

Commit 1 alone yields a working authenticated state; commit 2 is pure cleanup.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| HM sops can't decrypt `passwords.yaml` | Low | `.sops.yaml` `secrets/shared/.+` includes `admin_glats`; `shared/opencode.nix` pattern proves shared-file decryption works |
| Dual sops namespace confusion | Low | NixOS `/run/secrets/github/pat` (MCP wrapper) vs HM `~/.config/sops-nix/secrets/github/pat` (zsh) — independent |
| `GH_TOKEN` only in interactive zsh | Low (spec-acceptable) | `gh` only from shell; git uses `gitCredentialHelper`; MCP reads sops directly |
| PAT scope (`gho_` may lack `repo`/`read:org`) | Medium | Verify in GitHub UI before apply; re-issue + re-encrypt via `sops secrets/shared/passwords.yaml` if needed |
| Rog unmanaged `~/.git-credentials` | None | We never materialize it; HM won't touch it |

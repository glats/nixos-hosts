# Archive: multi-github-identity

## Summary

Implemented dual GitHub identity management (glats personal + jcuzmar work) across all four hosts (rog, thinkcentre, t14, mact2) using git `includeIf`, dual MCP server wrappers, and per-identity GPG signing via sops-deployed keys.

## Artifacts

| Artifact | Path |
|----------|------|
| Exploration | `openspec/changes/multi-github-identity/exploration.md` |
| Proposal | `openspec/changes/multi-github-identity/proposal.md` |
| Spec — Git Config | `openspec/changes/multi-github-identity/specs/git-config/spec.md` |
| Spec — Secrets | `openspec/changes/multi-github-identity/specs/secrets/spec.md` |
| Spec — MCP | `openspec/changes/multi-github-identity/specs/mcp/spec.md` |
| Spec — Cleanup | `openspec/changes/multi-github-identity/specs/cleanup/spec.md` |
| Design | `openspec/changes/multi-github-identity/design.md` |
| Tasks | `openspec/changes/multi-github-identity/tasks.md` |

## Actual vs Planned

| Metric | Planned | Actual |
|--------|---------|--------|
| Changed lines | ~160 | 2316 (+129 -) |
| Changed files | 13 | 27 |
| Phases | 3 | 3 (plus extras) |
| PR size risk | Low | High (exceeded 400-line budget, single PR acceptable by orchestration decision) |

### Deviations from Plan

| Aspect | Planned | Actual | Reasoning |
|--------|---------|--------|-----------|
| GPG on Linux | None — Linux had no GPG | Added `home-linux/gpg.nix` with full dual-key import | Both identities needed signing; user had jcuzmar GPG key working on macOS and wanted same for glats on Linux |
| GPG key import | Only fingerprint in sops | Full key pair (fingerprint + private key) per identity in sops, with activation script | Private key must be deployed via sops for automated import — fingerprint alone is not importable |
| Signing key format | Hardcoded fingerprint style | `signingKey` field in `shared/git-identity.nix` as plain attribute | Moved to identity definition for per-identity signing support; keeps signing key as plain text (it's public info, not a secret) |
| Linux GPG support | Not planned | `home-linux/gpg.nix` created, added to `home-linux/shared-modules.nix` | Essential for dual GPG signing on Linux hosts |
| macOS gpg.nix | Not modified | Refactored to match Linux pattern — dual-key import activation script | Cross-platform consistency |
| Token lifecycle | Not planned | Added `github-token-check.nix` activation script + shell async warning | Proactive token expiry detection prevents MCP startup failures |
| Setup guide | Not planned | `docs/multi-github-identity.md` (188 lines) | Essential manual steps (sops edit, GPG key generation) needed documentation |
| `shared/sops.nix` | Add 2 secrets | Added 6 secrets (`pat_jcuzmar`, `gpg_jcuzmar_fingerprint`, `gpg_jcuzmar_key`, `gpg_glats_fingerprint`, `gpg_glats_key`, plus `pat_jcuzmar` already declared) | Full key deployment requires both fingerprint and private key per identity |
| `modules/base/sops.nix` | Not planned | Added `github/pat` and `github/pat_jcuzmar` at system level | Linux MCP wrappers are system-level services that need system-level sops secrets |

### Scope Changes

1. **GPG expanded**: The original spec (SEC-REQ-2) planned only moving the fingerprint to sops. The implementation adds full GPG key pair (fingerprint + private key) import via sops + HM activation script, on both Linux and macOS. This was driven by the requirement for both identities to sign commits.

2. **Token lifecycle management**: Two unplanned features were added — `github-token-check.nix` (system activation script that validates both PATs during `nixos-build switch`) and async shell expiry warning in `home-linux/shell.nix`. This improves operational hygiene beyond the original scope.

3. **Setup documentation**: `docs/multi-github-identity.md` was created to guide the user through manual sops edits, GPG key generation, and first-time key import. Not planned in the spec but essential for usability.

4. **GPG per-identity signing in `shared/git-identity.nix`**: The identity definitions include `signingKey` as a plain attribute. This is public information (GPG fingerprint) and intentionally not stored in sops — it goes into the git config directly from the Nix module.

## Verification Results

- `nix flake check --no-build`: Passes for rog, thinkcentre, t14. mact2 not locally verifiable (nix-darwin).
- `format-nix`: Applied across all changed files.
- GPG signing confirmed working on Linux (glats key after last fix a1a0134).
- Git identity switching confirmed: `~/Work/**` → jcuzmar, `~/dev/**` → glats on Linux.
- Dual MCP entries (`github-glats`, `github-jcuzmar`) both enabled in MCP config.
- Legacy `~/.git-[redacted]` removed from config (no longer created).
- `git-credentials.yaml` removed from repository.

## Deployed Hosts

| Host | Status | Identity Default | Override |
|------|--------|-----------------|----------|
| rog | Deployed | glats | ~/Work/** → jcuzmar |
| thinkcentre | Deployed | glats | ~/Work/** → jcuzmar |
| t14 | Deployed | glats | ~/Work/** → jcuzmar |
| mact2 | Deployed | jcuzmar | ~/Personal/** → glats |

## Key Decisions Made During Implementation

1. **Dual GPG key import via sops**: Required both fingerprint and private key secrets in sops. Fingerprint is public info stored as plain text in `git-identity.nix`; private key is encrypted in sops and imported via activation script.

2. **Linux GPG support**: Added GPG signing for both identities on Linux (not in original plan) to match macOS behavior and enable signed commits from both identities on all hosts.

3. **glats.signingKey initially empty**: First version left glats' signingKey as `""` with `lib.optionalAttrs` to conditionally enable it. Final version (a1a0134) set the actual fingerprint after GPG key was generated on Linux.

4. **Token validation**: Added both system-level activation script and shell-level async check to catch expired tokens early — operational improvement beyond the scope.

5. **macOS-specific pinentry**: `home-darwin/gpg.nix` uses `pinentry_mac` while `home-linux/gpg.nix` uses `pinentry-curses`. Platform-appropriate choice.

## Open Items (Deferred)

- GH_TOKEN for jcuzmar on Linux remains manual (`gh auth login` when needed).
- Per-repo remote URL switching (personal repos using `git@github-personal` SSH alias) left to user convention.
- GPG key rotation process not documented — assumes user runs `gpg --full-generate-key` and updates sops + git-identity.nix.

## PR

- GitHub PR #3: `feat(git): multi-github-identity with dual GPG keys and MCP wrappers`
- Branch: `feat/multi-github-identity`
- Target: `master`
- State: Open, ready to merge

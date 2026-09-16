# Tasks: Harden macm5 Apple Silicon Onboarding

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 450–650 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 hardening/identity → PR 2 native evidence/runbook → PR 3 gated retirement |
| Delivery strategy | exception-ok |
| Chain strategy | size:exception accepted by maintainer |

Decision needed before apply: No — maintainer accepted `size:exception` for this coherent remote-safe slice
Chained PRs recommended: Yes, but not required for this accepted slice
Chain strategy: size:exception
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Determinate settings and unique identity | PR 1 | `format-nix && nix flake check --no-build` | Native preflight; no mact2 | Revert settings, identity declarations, and ciphertext rotation |
| 2 | Native bootstrap, evidence, and recovery | PR 2 | `nix flake check --no-build` | macm5 first switch and acceptance checklist | Revert runbook/docs; restore macm5 generation only |
| 3 | Evidence-gated retirement | PR 3 | `nix flake check --no-build` | Acceptance record then macm5-only retirement rehearsal | Revert declarative retirement; never reactivate mact2 |

## Phase 1: RED Gates and Foundation

- [ ] 1.1 RED: add preflight harness for fresh Determinate-only state, `/nix` APFS mount, daemon socket, and PATH; failed checks MUST stop before activation or retirement (runtime: native macm5 only).
- [ ] 1.2 RED: add lifecycle harness proving absent/failed acceptance keeps mact2 records and that pre-staged macm5 authentication fails safely; scan repository, Nix store, and logs for UUID leakage.
- [ ] 1.3 RED: add retirement guard test proving absent/failed native evidence leaves `flake.nix`, `hosts/mact2/default.nix`, remote-access declarations, and SOPS identity records unchanged.
- [x] 1.4 Define acceptance evidence location and authorization format in `docs/macm5-migration.md`; ciphertext only, never decrypt or commit UUID plaintext.

## Phase 2: Determinate and Identity Production Work

- [x] 2.1 Move Darwin daemon/cache values to `darwin/system/nix.nix`, `darwin/system/cachix.nix`, and `shared/cachix.nix` via `determinateNix.customSettings`; retain `nix.enable = false` and Linux behavior.
- [x] 2.2 Add the `uuid_macm5` recipient/key/user across the Darwin client, rog server declarations, `.sops.yaml`, and sing-box VLESS users; leave `mact2` unchanged and document the admin-only ciphertext rotation procedure.

## Phase 3: Native Acceptance and Runbook

- [x] 3.1 Update `hosts/macm5/default.nix`, `darwin/system/settings.nix`, and `darwin/home/remote-desktop.nix` for macm5-only onboarding; preserve arm64 Homebrew and direct-default routing.
- [x] 3.2 Write `docs/macm5-migration.md`, `docs/sops-new-host.md`, and `docs/home-link.md` covering evaluation, switch, `/nix`, Determinate launchd, PATH, Home Manager, Homebrew, SSH/Screen Sharing, wsdd, `sing-box check`, permissions, routing, and Git/generation recovery; mact2 MUST NOT appear as fallback, test, or rollback.
- [x] 3.3 Run native macm5 acceptance and record release evidence plus known-good generation; stop and recover on APFS or daemon-socket failure.

## Phase 4: Evidence-Gated Retirement

- [x] 4.1 After accepted evidence only, remove mact2 from `flake.nix`, delete `hosts/mact2/default.nix`, remove stale targets from `linux/home/remote-desktop.nix`, `linux/home/ssh.nix`, and `darwin/home/remote-desktop.nix`, then revoke required rog/SOPS records.
- [ ] 4.2 Run `format-nix && nix flake check --no-build`, verify macm5 remains healthy and mact2 authentication fails; recovery MUST use macm5 Git/generation/identity state only.

## Phase 5: Confirmed Corporate Identity Correction

- [x] 5.1 Decouple the logical Darwin configuration selector from the physical hostname in `mkDarwinHost`, `flake.nix`, and macm5 host configuration; configure local account `juan` and preserve `CLFTCLGV2FHWW0W` by omitting `networking.hostName`.
- [x] 5.2 Make Darwin `nixos-build` target `macm5` by default, document the `NIXOS_DARWIN_HOST` override, and add focused resolver tests.
- [x] 5.3 Replace the hard-coded Darwin user PATH entry with `primaryUser`, keep GitHub identity explicitly `jcuzmar`, and update macm5 onboarding artifacts.

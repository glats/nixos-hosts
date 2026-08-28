# Tasks: NixOS Architecture-Grounded Refactor Pass

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~206 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Delete proven dead code (darwin/default.nix orphan) | PR 1 | `test -e darwin/default.nix` (should fail) | `nix flake check --no-build` (rog, thinkcentre, t14) | `git revert` deletion bundle |
| 2 | Clean stale references (nix.nix comment, mkHost, conkyConfig, ghostty, romarr/grabarr) | PR 1 | `rg` patterns from dead-code spec | `nix flake check --no-build` | `git revert` deletion bundle |
| 3 | Consolidate rog timeouts (add romm-db to module, delete inline block) | PR 2 | `rg -n 'docker-romm-db' hosts/rog/systemd-timeouts.nix` (1 match) | `nix build .#nixosConfigurations.rog.config.system.build.toplevel --no-build` | `git revert` rog timeout commit |
| 4 | Fix HM composition ownership (remove prepend + bindings) | PR 3 | `rg -n 'linuxHomeModules|darwinHomeModules' flake.nix` (should be 0) | `nix build .#homeConfigurations.rog.activationPackage --no-build` | `git revert` composition commit |
| 5 | Sync AGENTS.md and comments (3 edits + 4 translations) | PR 4 | `rg -n 'appended per-host in flake.nix .homeConfigurations' AGENTS.md` (should be 0) | `nix flake check --no-build` | `git revert` docs/comments commit |

## Phase 1: Deletion Bundle (Atomic Commit)

_Delete proven dead code, stale references, and unused inputs. Zero-risk, all changes in a single atomic commit verified by `nix flake check --no-build` and `rg` patterns._

- [ ] **1.1** Delete `darwin/default.nix` — true orphan (zero import refs); stale duplicate of `hosts/mact2/default.nix` with drifted provider.  
  _Spec:_ `dead-code/spec.md` — Requirement 1 (orphan deleted), Scenario: file removed; `boot-timeouts/spec.md` indirectly verified.  
  _Verification:_ `test -e darwin/default.nix` → fail (file absent). `nix build .#darwinConfigurations.mact2.config.system.build.toplevel --no-build` → succeed (built from `hosts/mact2/default.nix` via `mkDarwinHost`).

- [ ] **1.2** Remove stale comment referencing `darwin/default.nix` from `darwin/system/nix.nix:2`.  
  _Spec:_ `dead-code/spec.md` — Requirement 2 (stale comment cleaned).  
  _Verification:_ `rg -n 'darwin/default.nix' darwin/system/nix.nix` → zero matches.

- [ ] **1.3** Delete `mkHost` alias from `lib/mkHost.nix:44,47` and remove unused destructure at `flake.nix:141`.  
  _Spec:_ `dead-code/spec.md` — Requirement 3 (mkHost alias removed): Scenario alias gone from lib; Scenario alias gone from flake.nix.  
  _Verification:_ `rg -n 'mkHost' lib/mkHost.nix` → only `mkNixosHost` matches (no `mkHost =` binding). `rg -n 'mkHost' flake.nix` → zero matches.

- [ ] **1.4** Delete `conkyConfig` specialArg from `linux/system/base/home-manager.nix:16`.  
  _Spec:_ `dead-code/spec.md` — Requirement 4 (conkyConfig specialArg removed): Scenario specialArg absent; Scenario standalone HM still builds.  
  _Verification:_ `rg -n 'conkyConfig' linux/system/base/home-manager.nix` → zero matches. `nix build .#homeConfigurations.rog.activationPackage --no-build` → succeed (conky modules use local bindings).

- [ ] **1.5** Remove unused `ghostty` flake input from `flake.nix:126-129` and regenerate `flake.lock`.  
  _Spec:_ `flake-inputs/spec.md` — Requirement 1 (ghostty input removed): Scenario ghostty absent from flake.nix; Scenario ghostty absent from flake.lock; Scenario no `inputs.ghostty` references. Requirement 2 (evaluation unaffected).  
  _Verification:_ `rg -n 'ghostty = \{' flake.nix` → zero matches. `rg -n '"ghostty"' flake.lock` → zero matches. `rg -n 'inputs\.ghostty' --glob '!flake.lock'` → zero matches. `nix flake check --no-build` → exit 0 for rog, thinkcentre, t14.

- [ ] **1.6** Delete commented `romarr.nix`/`grabarr.nix` imports from `hosts/rog/default.nix:63,65`.  
  _Spec:_ `dead-code/spec.md` — Requirement 5 (romarr/grabarr commented imports removed).  
  _Verification:_ `rg -n 'romarr\.nix|grabarr\.nix' hosts/rog/default.nix` → zero matches.

**Rollback:** `git revert` of the deletion bundle commit restores `darwin/default.nix`, `mkHost` alias, `conkyConfig` specialArg, `ghostty` input + `flake.lock`, and `romarr/grabarr` comments.

## Phase 2: Rog Timeout Consolidation

_Consolidate the two-source-of-truth for rog systemd timeouts. Move `docker-romm-db` into the single source module and delete the inline divergent block._

- [ ] **2.1** Add `docker-romm-db` entry to `hosts/rog/systemd-timeouts.nix` after line 14, matching the existing attrset pattern.  
  _Spec:_ `boot-timeouts/spec.md` — Requirement 1 (single source of truth module): Scenario romm-db present in module.  
  _Verification:_ `rg -n 'docker-romm-db' hosts/rog/systemd-timeouts.nix` → exactly one line with `TimeoutStartSec = lib.mkForce "300"`.

- [ ] **2.2** Delete entire inline timeout block at `hosts/rog/default.nix:187-201`, keeping the `./systemd-timeouts.nix` import at line 92.  
  _Spec:_ `boot-timeouts/spec.md` — Requirement 2 (inline duplicate block removed): Scenario no inline timeout overrides. Requirement 3 (module import intact). Requirement 4 (docker-romm-db evaluated exactly once).  
  _Verification:_ `rg -n 'systemd\.services\.(nginx|"acme-glats\.org"|"docker-droppy"|"docker-guacamoledb"|"docker-jellyfin"|"docker-jellyseerr"|"docker-romm-db")\.serviceConfig\.(TimeoutStartSec|startLimitIntervalSec)' hosts/rog/default.nix` → zero matches. `rg -n '\\./systemd-timeouts\.nix' hosts/rog/default.nix` → match (import line 92 still present). `nix build .#nixosConfigurations.rog.config.system.build.toplevel --no-build` → succeed with romm-db timeout still effective.

**Rollback:** `git revert` of the rog timeout commit restores the inline block at `hosts/rog/default.nix:187-201` and removes `docker-romm-db` from `hosts/rog/systemd-timeouts.nix`.

## Phase 3: HM Composition Prepend Removal

_Make per-host home files the sole owner of the platform shared module list. Remove the double-eval prepend from `mkHomeConfig` and the now-unused bindings._

- [ ] **3.1** Delete `linuxHomeModules` and `darwinHomeModules` `let` bindings from `flake.nix` (the `import ./linux/home/shared-modules.nix` and `import ./darwin/home/shared-modules.nix` lines).  
  _Spec:_ `home-manager-composition/spec.md` — Requirement 1 (mkHomeConfig does not prepend shared list): Scenario no `linuxHomeModules|darwinHomeModules` in flake.nix. Requirement 2 (shared-list bindings removed).  
  _Verification:_ `rg -n 'linuxHomeModules|darwinHomeModules' flake.nix` → zero matches.

- [ ] **3.2** Delete the NOTE comment chain from `flake.nix` referencing the Linux HM composition alignment refactor (the comment block explaining the old sync mechanism).  
  _Spec:_ `home-manager-composition/spec.md` — Requirement 2 (shared-list bindings removed): Scenario bindings absent.  
  _Verification:_ (See task 3.1 — `rg` above covers the deletion scope.)

- [ ] **3.3** Change `mkHomeConfig` modules expression in `flake.nix` from `(if nixpkgs.lib.hasSuffix "linux" system then linuxHomeModules else darwinHomeModules) ++ extraModules` to `extraModules`.  
  _Spec:_ `home-manager-composition/spec.md` — Requirement 1 (mkHomeConfig does not prepend shared list); Requirement 3 (per-host home file owns shared list — linux: `hosts/<host>/home/default.nix` imports `linux/home/shared-modules.nix` once; darwin: `darwin/home/default.nix` imports `darwin/home/shared-modules.nix` once). Requirement 4 (all four standalone entries build).  
  _Verification:_ `nix build .#homeConfigurations.rog.activationPackage .#homeConfigurations.thinkcentre.activationPackage .#homeConfigurations.t14.activationPackage .#homeConfigurations.mact2.activationPackage --no-build` — all four succeed. `nix flake check --no-build` passes.

**Rollback:** `git revert` of the composition commit restores `linuxHomeModules`/`darwinHomeModules` bindings and the `++ extraModules` prepend in `mkHomeConfig`.

## Phase 4: Docs + Comments Hygiene

_Sync `AGENTS.md` with repo reality and translate four Spanish comment clusters to English, preserving all technical facts._

- [ ] **4.1** Update AGENTS.md Rule 9 (line 104): Replace "appended per-host in `flake.nix` `homeConfigurations`" with "appended per-host in `hosts/rog/home/default.nix` (lines 12-13)".  
  _Spec:_ `docs-hygiene/spec.md` — Requirement 1 (conky/openfang rule correct): Scenario stale phrase removed; Scenario correct location documented.  
  _Verification:_ `rg -n 'appended per-host in flake.nix .homeConfigurations' AGENTS.md` → zero matches. `rg -n 'hosts/rog/home/default.nix' AGENTS.md` → match within the conky/openfang rule (rule 9).

- [ ] **4.2** Update AGENTS.md Flake Inputs table (lines 119-129): Add 11 missing inputs after `ghostty` removal; remove `ghostty` row. Ensure every declared input name in `flake.nix` `inputs = { ... }` appears in the table.  
  _Spec:_ `docs-hygiene/spec.md` — Requirement 2 (flake inputs table complete): Scenario every input present in table.  
  _Verification:_ For each name in `flake.nix` inputs block, `rg -n "\`$name\`" AGENTS.md` → every declared input name appears in the table (no omission).

- [ ] **4.3** Update AGENTS.md Structure block (lines 13-37): Fix subdirectory descriptions — `hardware/` → 8 files (was "nvidia, amd-laptop, asus-fan-control"), `network/` → 7 files (was "wireguard, ddclient, samba, ftp"), `media/` → 5 files (was "arr-stack, jellyfin, qbittorrent"); add missing entries: `services/` root has `github-token-check.nix` + `maquilinux-mounts.nix`; `hosts/<h>/home/` layer; `hosts/t14/hdm/`; `hosts/t14/home/hypr/`.  
  _Spec:_ `docs-hygiene/spec.md` — Requirement 3 (structure block accurate): Scenario stale descriptions removed.  
  _Verification:_ `rg -n 'hardware/.*# nvidia, amd-laptop, asus-fan-control$|network/.*# wireguard, ddclient, samba, ftp$|media/.*# arr-stack, jellyfin, qbittorrent$' AGENTS.md` → zero matches.

- [ ] **4.4** Translate Spanish comment cluster in `flake.nix:112-115` (homebrew-brew) to English, preserving technical facts: "fix de `to_sym for nil`" → "fix of `to_sym for nil`", "`--force-cleanup` (nix-darwin requerido)" → "`--force-cleanup` (nix-darwin required)".  
  _Spec:_ `docs-hygiene/spec.md` — Requirement 4 (four Spanish comment clusters translated): Scenario Spanish lexical markers absent in scoped range; Scenario technical facts preserved.  
  _Verification:_ `rg -n 'Resiliencia|requerido|ele funcionar|Reservar|Re-auditar|el retry|para los datos|Bind mounts para' flake.nix` → zero matches (in the homebrew-brew range). `rg -n '#41236' shared/opencode/providers-base.nix` → `#41236` remains present.

- [ ] **4.5** Translate Spanish comment cluster in `shared/opencode/providers-base.nix:168-214` (free-tier audit) to English, preserving all technical facts: `#41236`, tok/s numbers (70, 1.67s, 2.95s), SWE-Bench ~70-72%, GPQA 87, RULER@1M 94.7, Terminal-Bench 2.1: 24.6%, and all opencode issue references.  
  _Spec:_ `docs-hygiene/spec.md` — Requirement 4 (four Spanish comment clusters translated): Same verification as 4.4, applied to this range.  
  _Verification:_ Each scoped range grepped for `Resiliencia|requerido|su ele funcionar|Reservar|Re-auditar|el retry|para los datos|Bind mounts para` → zero matches. `rg -n '#41236' shared/opencode/providers-base.nix` → `#41236` remains present. `rg -n 'falla rápido|falla rapido' shared/nix-resilience.nix` → resilience benchmark intent (fast-fail timeouts) preserved in English.

- [ ] **4.6** Translate Spanish comment cluster in `shared/nix-resilience.nix:16-21` (resilience) to English, preserving "falla rápido" (fast-fail) and timeout values (30, 50, 3, 5, true).  
  _Spec:_ `docs-hygiene/spec.md` — Requirement 4 (four Spanish comment clusters translated): Same verification.  
  _Verification:_ `rg -n 'falla rápido|falla rapido' shared/nix-resilience.nix` → resilience benchmark intent preserved in English. `rg -n 'Resiliencia' shared/nix-resilience.nix` → zero matches (Spanish marker removed).

- [ ] **4.7** Translate Spanish comment cluster in `linux/system/services/web/code-server.nix:22` ("Bind mounts para los datos de code-server") to English "Bind mounts for code-server data".  
  _Spec:_ `docs-hygiene/spec.md` — Requirement 4 (four Spanish comment clusters translated): Same verification.  
  _Verification:_ `rg -n 'Bind mounts para los datos de code-server' linux/system/services/web/code-server.nix` → zero matches. `rg -n 'Bind mounts for code-server data' linux/system/services/web/code-server.nix` → match (English translation present).

**Rollback:** `git revert` of the docs/comments commit restores `AGENTS.md` and all Spanish comment clusters to their original state.

## Cross-Cutting Verification

Run these checks end-to-end after all 4 bundles are applied:

- [ ] **5.1** `format-nix && nix flake check --no-build` baseline for rog, thinkcentre, t14 — all must exit 0.
- [ ] **5.2** `rg` zero-reference proofs for all deleted symbols:
  - `test -e darwin/default.nix` → fail
  - `rg -n 'darwin/default.nix' darwin/system/nix.nix` → zero matches
  - `rg -n 'mkHost' lib/mkHost.nix` → only mkNixosHost
  - `rg -n 'mkHost' flake.nix` → zero matches
  - `rg -n 'conkyConfig' linux/system/base/home-manager.nix` → zero matches
  - `rg -n 'ghostty = \{' flake.nix` → zero matches
  - `rg -n '"ghostty"' flake.lock` → zero matches
  - `rg -n 'romarr\.nix|grabarr\.nix' hosts/rog/default.nix` → zero matches
  - `rg -n 'systemd\.services\.(nginx|"acme-glats\.org"|...|"docker-romm-db")\.serviceConfig\.(TimeoutStartSec|startLimitIntervalSec)' hosts/rog/default.nix` → zero matches
  - `rg -n 'linuxHomeModules|darwinHomeModules' flake.nix` → zero matches
  - `rg -n 'appended per-host in flake.nix .homeConfigurations' AGENTS.md` → zero matches
  - `rg -n 'hardware/.*# nvidia, amd-laptop, asus-fan-control$|network/.*# wireguard, ddclient, samba, ftp$|media/.*# arr-stack, jellyfin, qbittorrent$' AGENTS.md` → zero matches
- [ ] **5.3** Build all standalone HM activation packages: `nix build .#homeConfigurations.rog.activationPackage .#homeConfigurations.thinkcentre.activationPackage .#homeConfigurations.t14.activationPackage .#homeConfigurations.mact2.activationPackage --no-build` — all four succeed.
- [ ] **5.4** `nix build .#nixosConfigurations.rog.config.system.build.toplevel --no-build` — succeeds with romm-db timeout effective.

**Next:** Ready for `sdd-apply`. The orchestrator will wait for user approval before launching apply (delivery_strategy = ask-on-risk requires explicit `Yes` before any `nixos-rebuild switch`).
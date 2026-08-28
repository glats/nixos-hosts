# Design: NixOS Architecture-Grounded Refactor Pass

## Technical Approach

This change implements five graph-grounded refactor opportunities from exploration v3, grouped into four ordered commit bundles. Each bundle is behavior-neutral and verified by `format-nix && nix flake check --no-build` (plus standalone HM activation package builds for the composition bundle). The design traces directly to the five delta specs under `openspec/changes/nixos-refactor-pass/specs/`.

## Architecture Decisions

### Decision: Deletion Bundle Commit Grouping

**Choice**: Single atomic commit for all four deletions (darwin/default.nix, mkHost alias, conkyConfig specialArg, ghostty input).

**Alternatives considered**: Split into 2–4 separate commits.

**Rationale**: All four deletions are independent, zero-risk, and verified by the same gate (`nix flake check --no-build` passes for rog/thinkcentre/t14). Grouping keeps history clean and avoids intermediate states where flake.lock is regenerated but ghostty input still declared (or vice versa). The ghostty removal regenerates flake.lock — committing it together with the input deletion is the only coherent state.

**Verification**: After commit, `nix flake check --no-build` passes for all three Linux hosts; `rg` confirms zero refs to deleted symbols.

---

### Decision: Rog Timeout Consolidation Mechanics

**Choice**: Add `docker-romm-db` entry to `hosts/rog/systemd-timeouts.nix` matching the existing attrset pattern (`systemd.services."docker-romm-db".serviceConfig.TimeoutStartSec = lib.mkForce "300";`), then delete the entire inline block at `hosts/rog/default.nix:187-201`. The module import at `hosts/rog/default.nix:92` (`./systemd-timeouts.nix`) stays untouched.

**Alternatives considered**: Keep inline block, move only romm-db to module; or inline everything and delete module.

**Rationale**: The module `hosts/rog/systemd-timeouts.nix` is already the declared single source of truth (imported at line 92). The inline block duplicates 6 of 7 services and diverges only by adding `docker-romm-db`. Merging the missing entry into the module and deleting the inline block eliminates the two-source-of-truth smell completely. The attrset shape in the module uses quoted service names with dots (e.g., `"acme-glats.org"`) — romm-db follows the same pattern.

**Verification**: 
- `rg -n 'docker-romm-db' hosts/rog/systemd-timeouts.nix` → exactly one line with `TimeoutStartSec = lib.mkForce "300"`
- `rg -n 'systemd\.services\.(nginx|"acme-glats\.org"|"docker-droppy"|"docker-guacamoledb"|"docker-jellyfin"|"docker-jellyseerr"|"docker-romm-db")\.serviceConfig\.(TimeoutStartSec|startLimitIntervalSec)' hosts/rog/default.nix` → zero matches
- `rg -n '\./systemd-timeouts\.nix' hosts/rog/default.nix` → import line 92 still present
- `nix build .#nixosConfigurations.rog.config.system.build.toplevel --no-build` succeeds

---

### Decision: HM Composition Owner — Per-Host Files Win

**Choice**: Per-host `home/default.nix` files become the sole owner of the platform shared module list. `mkHomeConfig` in `flake.nix` drops the prepend of `linuxHomeModules`/`darwinHomeModules` and the associated `let` bindings + NOTE comment chain (lines ~174–187, 195).

**Alternatives considered**: Keep prepend in `mkHomeConfig`, remove internal imports from per-host files.

**Rationale**: Exploration v3 confirmed every per-host home file already imports its platform shared list internally (rog/thinkcentre/t14 import `linux/home/shared-modules.nix`; mact2 via `darwin/home/default.nix` imports `darwin/home/shared-modules.nix`). The `mkHomeConfig` prepend causes double evaluation (module system dedups identical paths, so behavior-neutral today). Making per-host files the owner aligns with the explicit-import philosophy in AGENTS.md (rule 2: flat imports, no profile chains) and removes the two-source-of-truth smell.

**Code changes in flake.nix**:
- Delete lines 174–187 (NOTE comment chain + `linuxHomeModules`/`darwinHomeModules` bindings)
- In `mkHomeConfig` (lines 190–204): replace line 195 `(if ... then linuxHomeModules else darwinHomeModules) ++ extraModules` with just `extraModules`
- The `extraSpecialArgs` schema (lines 197–203) differs per platform (Darwin adds `primaryUser`, `javaVersion`; Linux does not) — this is preserved as-is since it's orthogonal to module list ownership.

**Verification protocol (lazy, ponytail-aligned)**:
1. Before change: `nix build .#homeConfigurations.rog.activationPackage .#homeConfigurations.thinkcentre.activationPackage .#homeConfigurations.t14.activationPackage .#homeConfigurations.mact2.activationPackage --no-build` — all four succeed
2. After change: same command — all four succeed
3. `nix flake check --no-build` passes
4. Optional: `nix eval .#homeConfigurations.rog.modules` (or similar) to confirm identical module closure — skipped unless a diff appears in step 2

---

### Decision: AGENTS.md Minimal Edit Set

**Choice**: Three targeted edits:

1. **Rule 9 (line 104)**: Replace "appended per-host in `flake.nix` `homeConfigurations`" with "appended per-host in `hosts/rog/home/default.nix` (lines 12-13)".
2. **Flake Inputs table (lines 119–129)**: Add the 11 missing inputs after ghostty removal: `nix-colors`, `omarchy-nix`, `nixos-hardware`, `hyprdynamicmonitors`, `claude-code-nix`, `gentle-ai-src`, `caveman-src`, `ponytail-src`, `engram-src`, `asus-fan-control-src`, `pipewire-module-xrdp-src`, `thinkfan-ui-src`, `determinate`, `nix-homebrew`, `homebrew-brew`, `nix-vscode-extensions`. (ghostty row removed.)
3. **Structure block (lines 13–37)**: Update subdirectory descriptions to reflect actual file counts:
   - `hardware/` → 8 files (was "nvidia, amd-laptop, asus-fan-control")
   - `network/` → 7 files (was "wireguard, ddclient, samba, ftp")
   - `media/` → 5 files (was "arr-stack, jellyfin, qbittorrent")
   - Add missing entries: `services/` root has `github-token-check.nix` + `maquilinux-mounts.nix`; `hosts/<h>/home/` layer; `hosts/t14/hdm/`; `hosts/t14/home/hypr/`

**Rationale**: Minimal edits that bring docs in line with explored reality. No restructuring of AGENTS.md.

---

### Decision: Spanish Comment Clusters — English-Only Translation

**Choice**: Translate four clusters verbatim, preserving all technical facts (issue refs, benchmarks, version numbers).

| Cluster | File | Lines | Key Facts to Preserve |
|---------|------|-------|----------------------|
| homebrew-brew | `flake.nix` | 112–115 | "fix de `to_sym for nil`", "`--force-cleanup` (nix-darwin requerido)" |
| free-tier audit | `shared/opencode/providers-base.nix` | 168–214 | `#41236`, tok/s numbers (70, 1.67s, 2.95s), SWE-Bench ~70-72%, GPQA 87, RULER@1M 94.7, Terminal-Bench 2.1: 24.6%, opencode#44300, #43690, #43837, #44382, #44044, #44385, opencode#43882, #44086, #43913 |
| resilience | `shared/nix-resilience.nix` | 16–21 | "falla rápido" (fast-fail), timeout values (30, 50, 3, 5, true) |
| bind mounts | `linux/system/services/web/code-server.nix` | 22–29 | "Bind mounts para los datos de code-server", paths `/srv/glats/code/project:/home/glats/project`, etc. |

**Rationale**: English-only register per project convention. No tone drift — technical facts are the signal.

## Data Flow

Current composition graph (simplified):

```
flake.nix
  ├─ mkNixosHost (lib/mkHost.nix) ──→ nixosConfigurations.{rog,thinkcentre,t14}
  │     ├─ imports hosts/<host>
  │     ├─ sops-nix, HM nixosModule, linux overlay
  │     └─ HM.extraSpecialArgs = {inputs, username}
  │
  ├─ mkDarwinHost (lib/mkDarwinHost.nix) ──→ darwinConfigurations.mact2
  │     ├─ imports hosts/mact2
  │     ├─ determinate, darwin overlay
  │
  ├─ mkHomeConfig ──→ homeConfigurations.{rog,thinkcentre,t14,mact2}
  │     ├─ BEFORE: prepends linuxHomeModules/darwinHomeModules ++ extraModules
  │     └─ AFTER: extraModules only (per-host files import shared list internally)
  │
  └─ packages output (lib/packages.nix + overlays)
```

After change: `mkHomeConfig` no longer prepends shared lists; per-host `home/default.nix` files are the sole composition owners. All other flows unchanged.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `darwin/default.nix` | Delete | True orphan (zero import refs); stale duplicate of `hosts/mact2/default.nix` with drifted provider |
| `darwin/system/nix.nix` | Modify | Line 2: remove stale comment referencing deleted `darwin/default.nix` |
| `lib/mkHost.nix` | Modify | Lines 44,47: delete `mkHost = mkNixosHost` alias |
| `flake.nix` | Modify | Line 141: remove `mkHost` from destructure; lines 126–129: delete `ghostty` input; lines 174–187: delete NOTE chain + `linuxHomeModules`/`darwinHomeModules` bindings; line 195: change `modules = (if ... then linuxHomeModules else darwinHomeModules) ++ extraModules` → `modules = extraModules` |
| `linux/system/base/home-manager.nix` | Modify | Line 16: remove `conkyConfig = config.conky-config;` from `extraSpecialArgs` |
| `hosts/rog/default.nix` | Modify | Lines 63,65: delete commented `romarr.nix`/`grabarr.nix` imports; lines 187–201: delete entire inline timeout block (import at line 92 stays) |
| `hosts/rog/systemd-timeouts.nix` | Modify | Add `systemd.services."docker-romm-db".serviceConfig.TimeoutStartSec = lib.mkForce "300";` (after line 14) |
| `AGENTS.md` | Modify | Rule 9, Flake Inputs table, Structure block — per docs sync decision |
| `flake.nix` | Modify | Line 112: translate Spanish comment to English |
| `shared/opencode/providers-base.nix` | Modify | Lines 168–214: translate Spanish comments to English, preserve all facts |
| `shared/nix-resilience.nix` | Modify | Lines 16–21: translate Spanish comments to English |
| `linux/system/services/web/code-server.nix` | Modify | Line 22: translate "Bind mounts para los datos de code-server" to English |

## Interfaces / Contracts

No new interfaces. The change removes unused plumbing and consolidates existing definitions. The `extraSpecialArgs` schema for `mkHomeConfig` remains platform-differentiated (Darwin gets `primaryUser`, `javaVersion`; Linux does not) — this is intentional and out of scope for unification.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit (grep) | Deleted symbols absent | `rg` patterns from each spec's scenarios |
| Integration | Flake evaluation | `nix flake check --no-build` for rog, thinkcentre, t14 |
| Integration | Standalone HM builds | `nix build .#homeConfigurations.{rog,thinkcentre,t14,mact2}.activationPackage --no-build` |
| Integration | rog system build | `nix build .#nixosConfigurations.rog.config.system.build.toplevel --no-build` |
| E2E | N/A | No runtime behavior change; full switch not required |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary changes.

## Migration / Rollout

No migration required. Pure refactor with git-revert rollback per commit group.

## Open Questions

- [ ] None — all decisions resolved from exploration evidence and spec requirements.

## Risk Mitigations (Mapped to Spec Scenarios)

| Spec | Risk | Mitigation |
|------|------|------------|
| dead-code | darwin/default.nix external consumer | Exploration confirmed zero in-repo refs; `darwinConfigurations.mact2` uses `mkDarwinHost` → `hosts/mact2/default.nix` |
| dead-code | conkyConfig removal breaks HM | Verified unconsumed: conky-rog.nix:167 and conky-thinkcentre.nix:167 define local `let conkyConfig = ...` that shadows |
| boot-timeouts | romm-db timeout lost | Explicitly added to module; verified by grep count (1 in module, 0 in default.nix) |
| home-manager-composition | Double-eval removal breaks HM | Module system dedups identical paths; build all 4 activationPackages before/after as proof |
| flake-inputs | flake.lock churn breaks CI | Commit input deletion + lock regeneration atomically |
| docs-hygiene | AGENTS.md drift | Edits are mechanical (rule rewrite, table completion, count updates); verified by grep scenarios |

## Out of Scope (Restated)

Per proposal and specs, the following are explicitly **out of scope** and tracked as follow-up changes:
- specialArgs schema unification (four coexisting schemas)
- btop-omarchy decoupling (thinkcentre/mact2 theme dependency)
- conky pair consolidation (~97% duplicate between conky-rog/conky-thinkcentre)
- mkEnableOption guards for amd-laptop/keyring (PAM lock risk)
- t14 i18n parameterization, rog secrets mapAttrs refactor, path hardcoding hygiene

## Rollback

Pure `git revert` per commit group:
1. Revert deletion bundle commit → restores darwin/default.nix, mkHost alias, conkyConfig, ghostty input + flake.lock
2. Revert rog timeout commit → restores inline block, removes romm-db from module
3. Revert composition commit → restores linuxHomeModules/darwinHomeModules bindings + prepend in mkHomeConfig
4. Revert docs/comments commit → restores AGENTS.md + Spanish comments

The ghostty commit isolates flake.lock churn; reverting it restores the prior lockfile.

## Architecture Notes: Composition Graph Delta

**Before**:
```
mkHomeConfig → [linuxHomeModules|darwinHomeModules] ++ extraModules
  │
  └─ extraModules = import ./hosts/<host>/home/default.nix { inputs }
       │
       └─ hosts/<host>/home/default.nix → imports shared-modules.nix internally
```
Result: shared list evaluated twice (deduped by module system).

**After**:
```
mkHomeConfig → extraModules
  │
  └─ extraModules = import ./hosts/<host>/home/default.nix { inputs }
       │
       └─ hosts/<host>/home/default.nix → imports shared-modules.nix (sole owner)
```
Result: shared list evaluated exactly once per host. Behavior-neutral by module dedup semantics.
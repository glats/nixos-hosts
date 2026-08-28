# Proposal: NixOS Architecture-Grounded Refactor Pass

## Intent

Exploration v3 traced entry points and reachability across 210 `.nix` files: exactly one true orphan, dead plumbing, one structural duplication, and docs/comment drift. This change deletes proven dead code, fixes a two-source-of-truth composition smell, and syncs docs — no behavior changes intended.

## Scope

### In Scope

1. **Zero-risk deletion bundle** (hosts affected: mact2 path only; eval all)
   - Delete `darwin/default.nix` — sole true orphan (zero import refs); stale duplicate of `hosts/mact2/default.nix` with drifted provider (`"opencode-free"` :48 vs live `"github-copilot-safe"` at `hosts/mact2/default.nix`:52). Clean stale comment mentions (`darwin/system/nix.nix`:2, `flake.nix`:292-296).
   - Delete dead `mkHost` alias (`lib/mkHost.nix`:44,47) and unused destructure (`flake.nix`:141).
   - Delete unconsumed `conkyConfig` specialArg (`linux/system/base/home-manager.nix`:16; zero consumers; shadowed by local lets in `linux/home/conky-*.nix`:167).
   - Remove unused `ghostty` flake input (`flake.nix`:126-129; zero `inputs.ghostty` refs; regenerate `flake.lock`).
2. **Rog timeout consolidation** (host: rog) — inline block `hosts/rog/default.nix`:187-201 duplicates imported `hosts/rog/systemd-timeouts.nix`:9-22 and diverges (`docker-romm-db` TimeoutStartSec exists only inline :193). Add romm-db to the module, delete inline block. Module import at rog/default.nix:92 stays.
3. **HM standalone composition ownership fix** (hosts: rog, thinkcentre, t14, mact2) — verified in code: every per-host home file imports its platform shared list internally, while `mkHomeConfig` prepends it again (`flake.nix`:195) → shared list evaluated twice in all 4 standalone entries (module dedup keeps it behavior-neutral today). Direction: per-host home files stay sole owner; drop the prepend plus now-unused `linuxHomeModules`/`darwinHomeModules` bindings (:181-187) and the NOTE comment chain (:174-180).
4. **Docs + comments hygiene** (all hosts) — sync AGENTS.md with reality: conky-rog/openfang rule now lives in `hosts/rog/home/default.nix`:12-13, input table omits 11 real inputs, structure counts stale. Translate 4 Spanish comment clusters to English preserving technical facts: `flake.nix`:112, `shared/opencode/providers-base.nix`:172-214+, `shared/nix-resilience.nix`:19-23, `linux/system/services/web/code-server.nix`:22.

### Out of Scope

- specialArgs schema unification (design-gated)
- btop-omarchy decoupling (affects mact2/thinkcentre themes; design-gated)
- conky pair consolidation (~97% duplicate; follow-up candidate)
- mkEnableOption guards for amd-laptop/keyring (PAM lock risk)
- t14 i18n parameterization, rog secrets mapAttrs refactor, path hardcoding hygiene

## Capabilities

### New Capabilities
None.

### Modified Capabilities
None. Pure refactor — existing specs (`boot`, `hardware-nvidia`) cover kernel selection and nvidia config; timeout values are unchanged behavior from a single source.

## Approach

Ordered commits: deletion bundle first (atomic), then rog consolidation, then composition fix, docs last. Every commit gated by the verification contract below.

## Affected Areas

| Area | Impact | Hosts | Description |
|------|--------|-------|-------------|
| `darwin-host-config` | Removed | mact2 | Orphan deleted; live path untouched |
| `flake-inputs` | Modified | all | ghostty removed; lock regenerated |
| `home-manager-composition` | Modified | rog, thinkcentre, t14, mact2 | Single shared-list owner |
| `rog-timeouts` | Modified | rog | romm-db moved into module |
| `docs-hygiene` | Modified | all | AGENTS.md + comments |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Composition change breaks standalone HM eval | Low | Build all 4 activationPackages before/after |
| Concurrent edit on providers-base.nix | Low | Exploration saw uncommitted edits there; tree verified clean 2026-08-23 — re-check `git status` before touching it |
| flake.lock churn breaks CI | Low | Commit lock together with input removal |

## Rollback Plan

Pure `git revert` per commit; the deletion bundle commits atomically. No state or data migration involved.

## Dependencies

None.

## Verification Plan

Per commit: `format-nix && nix flake check --no-build`. For item 3 additionally build all standalone HM entries: `nix build .#homeConfigurations.<user>@<host>.activationPackage` (rog, thinkcentre, t14, mact2). Final pass: grep confirms zero references to deleted symbols.

## Success Criteria

- [ ] `nix flake check --no-build` passes for rog, thinkcentre, t14
- [ ] All 4 homeConfigurations activation packages build
- [ ] Zero references remain to `darwin/default.nix`, `mkHost` alias, `conkyConfig` specialArg, `inputs.ghostty`
- [ ] `docker-romm-db` TimeoutStartSec evaluated exactly once via module
- [ ] Four comment clusters English-only; AGENTS.md matches repo reality
- [ ] Total diff within 400-line review budget

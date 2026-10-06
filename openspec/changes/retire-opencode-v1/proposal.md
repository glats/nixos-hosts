# Proposal: Retire OpenCode V1

## Intent

Remove redundant active V1 maintenance across rog, thinkcentre, t14 and macm5. The operator accepts V2 stability and retains `opencode2`/`opencode2-home`.

## Scope

### In Scope
- Remove V1 packages, exports, runtime emission and V1-only plugin wiring.
- Retarget or retire V1-coupled helpers without broken defaults; retain OpenFang skill sync using V2 assets.
- Preserve V2 isolation, server identity, proxy/standalone launch behavior, MCP, Engram, providers, credentials and sessions.

### Out of Scope
- Bare `opencode` compatibility alias, default-root cutover, Gentle AI v3/v4 or ODD migration.
- Secret deletion/decryption, destructive credential merging, session conversion, garbage collection, activation or commits in this phase.

## Capabilities

### New Capabilities
- `opencode-v1-retirement`: V2-only active delivery with archival V1 data and safe helper defaults.

### Modified Capabilities
- `gentle-ai-declarative-runtime`: retire V1 lifecycle requirements while retaining V2 grants, assets and pinned ownership.
- `opencode-runtime-proxy`: native runtime proof uses isolated V2 entry points.
- `macm5-openai-native-auth`: V2 smoke/bootstrap target and safe auth-seed fallback.
- `macm5-openai-tls-tunnel`: V2 launcher executable wiring; preserve conditional proxy and MCP isolation.

## Approach

Use exploration approach 1, admitted against matching hybrid preproposal revision 1; research is unselected. Keep Gentle AI v2.5.0 and current V2/SDK pins. Remove only verified V1-exclusive dependencies. Preserve/repoint shared `agents.nix`, `permissions.nix` and other helpers while V2 consumes them. Separate V1 emission from shared package/auth gates. Wire executable consumers deliberately through the isolated V2 environment: shell functions cannot satisfy `exec.LookPath`; raw-native substitution is insufficient.

## Affected Areas

| Paths | Impact |
|---|---|
| `pkgs/opencode/`, `pkgs/opencode-npm-packages/`, `lib/packages.nix`, `overlays/{linux,darwin}.nix` | Remove V1 delivery |
| `linux/system/base/profiles/dev.nix`, `darwin/home/packages.nix` | Remove host consumption |
| `shared/opencode.nix`, `shared/opencode/`, `shared/opencode-profile.nix`, `shared/shell-aliases.nix` | Preserve V2; trim V1 |
| `pkgs/nixos-scripts/`, `docs/home-link.md`, `docs/opencode-v2-final-cutover.md` | Repair helpers/documentation |

## Risks

Medium: shared dependencies and helper defaults can regress V2. Preserve existing dirty runtime/config/launcher-test/cutover-doc edits and untracked migration/credential-fix artifacts; never rewrite overlapping work.

## Rollback Plan

Revert only retirement-owned changes; restore known-good NixOS/Darwin/Home Manager generations. Retain V1 config/auth/session files untouched as archives and retain prior generations; no GC.

## Dependencies

Confirmed handoff and existing V2 assets; no upgrades or research gate.

## Success Criteria

- [ ] Zero active V1 delivery/config emission or broken helper defaults; OpenFang sync preserved.
- [ ] `nix flake check --no-build`; separately evaluate drvPaths for Linux toplevels rog/thinkcentre/t14, standalone HM activationPackages all four hosts, and Darwin macm5 toplevel.
- [ ] Go tests, `home-launcher.test.py`, generated V2 config/isolation comparisons, helper-default/auth/proxy/OpenFang regressions pass.
- [ ] Reachable runtime smoke passes without namespace changes; absent remote execution explicitly UNVERIFIED, never inferred from evaluations.

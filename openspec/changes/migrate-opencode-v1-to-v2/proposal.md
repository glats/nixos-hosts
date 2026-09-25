# Proposal: Parallel Isolated OpenCode V2 Runtime

## Intent

V2 (`@opencode/cli@2.0.14`, GA) shares V1's command and dirs, so a naive install clobbers V1. Add an isolated V2 runtime beside untouched V1 (explicit `opencode2`). Eventual V2 migration; V1 stays the fallback.

## Scope

### In Scope

- `pkgs/opencode-v2` from pinned npm platform tarballs (hash-pinned `fetchurl`; no postinstall/standalone binary).
- Native V2 shared background server (no daily `--standalone`); version-scoped isolation.
- `opencode`→V1 (unchanged), `opencode2`→V2 wrappers setting XDG base dirs + `OPENCODE_CONFIG_DIR`/`OPENCODE_DB`/`TMPDIR` in the V2 dir; no V1 fallback.
- Default V2 `OPENCODE_DISABLE_PROJECT_CONFIG=1`; opt-in limited to V2-compatible projects.
- Clean V2 auth; voluntary one-time V1 `auth.json` seed (proxy OAuth only).
- Cross-platform `home.activation` restart hook (`opencode2 service restart`, cmp-guarded); per-host eval + smoke test.

### Out of Scope

- V2 key remap / generator rewrite; V2 ports of 6 local + 3 npm plugins (deferred).
- systemd/launchd daemon.

## Capabilities

### New Capabilities

- `opencode-v2-runtime`: V2 binary + wrapper; isolated roots, shared server + restart hook, project-config policy, clean-auth + opt-in seed, no-auto-migration.

### Modified Capabilities

- `gentle-ai-declarative-runtime`: parameterize generator for the isolated V2 tree; V1 output byte-identical.
- `repo-agent-context`: project-root `AGENTS.md` discovery gated behind V2 opt-in.

## Approach

Chained PRs: package V2 → parameterize generator → isolated tree + wrappers + hook → per-host verify.

## Affected Areas

- `pkgs/opencode-v2/` (new) — V2 derivation.
- `shared/opencode.nix`, `runtime-config.nix` — parameterized generator; V2 tree.
- `lib/packages.nix`, `overlays/{linux,darwin}.nix` — register V2.
- `shared/shell-aliases.nix` — `opencode2` wrapper.
- `pkgs/nixos-scripts/cmd/install-opencode-auth-seed` — opt-in V2 seed.

## Risks

- Isolation env leak breaks V1 (High) — one HM function shared by wrapper + hook.
- Config capture on running server (Med) — cmp-guarded restart hook.
- One-way cli.json/auth migration (Med) — scoped to V2 dir; assert no V1 writes.
- Opt-in crosses boundary (Med) — refuse V1-SDK `.opencode/`.

## Rollback Plan

- **Package**: repoint `opencode-v2` to prior hash; remove derivation/wrapper.
- **Config**: HM/NixOS generations restore the prior tree.
- **Service lifecycle**: drop the cmp-guarded hook.
- **Same-folder isolation**: version-scoped roots; nothing to unwind.
- **Adoption gates**: disable opt-in wrapper; V1 stays default.
- **Credentials**: delete V2 DB → clean auth; V1 `auth.json` read-only.

## Success Criteria

- [ ] `opencode` = V1 1.18.32; `opencode2 --version` = 2.0.14; no postinstall.
- [ ] Wrapper sets all isolation vars in the V2 dir; V1 output byte-identical.
- [ ] Default V2 disables project config; opt-in is the only path and refuses a V1-SDK repo.
- [ ] Shared server registers under the V2 state root; hook fires only on config change; no daemon.
- [ ] Fresh V2 launch writes nothing under V1 dirs; seed leaves V1 `auth.json` unchanged.
- [ ] Same-folder coexistence smoke matrix passes on 4 hosts.

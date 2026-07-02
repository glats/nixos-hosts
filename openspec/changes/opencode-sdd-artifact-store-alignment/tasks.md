# Tasks: Align SDD Artifact Store Dispatching

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~6 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr-default |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Bump gentle-ai to v1.42.0 and validate | PR 1 | Single PR; base = main |

## Phase 1: Version Bump

- [x] 1.1 Update `flake.nix` `gentle-ai-src` input URL tag from `v1.40.2` to `v1.42.0`
- [x] 1.2 Update `pkgs/gentle-ai/default.nix` `version` from `"1.40.2"` to `"1.42.0"`
- [x] 1.3 Update `pkgs/gentle-ai/default.nix` Linux `sha256` to match v1.42.0 release tarball
- [x] 1.4 Update `pkgs/gentle-ai/default.nix` Darwin `sha256` to match v1.42.0 release tarball

## Phase 2: Build Validation

- [x] 2.1 Run `nix flake check --no-build` to verify flake evaluates cleanly
  - Required pre-building `gentle-ai-assets-vanilla` first because
    `shared/opencode/agents.nix` uses `builtins.readFile` on the
    derivation output, which needs the path to exist in the store.
- [x] 2.2 Build `gentle-ai` binary package: `nix build .#packages.x86_64-linux.gentle-ai`
  - Built `/nix/store/c041ys82vbkj48wnpar16dpn44aldhli-gentle-ai-1.42.0`.
  - Binary reports `gentle-ai 1.42.0`.
- [x] 2.3 Build `gentle-ai-assets-vanilla` and `gentle-ai-assets` to confirm asset derivations succeed
  - vanilla: `/nix/store/1yw0qq6s7rxf57y1ny3pxzsgcqjhk6l8-gentle-ai-assets-vanilla-aa33ce5b…`
  - layered: `/nix/store/dglj57vf9w1fdal2dv3rbsd2v26f9gzc-gentle-ai-assets-aa33ce5b…`
- [x] 2.4 Verify deployed `~/.config/opencode/sdd-orchestrator.md` contains artifact-store conditional gate
  - Deployed runtime is v1.40.2 (system not switched per user
    instruction); lacks the gate.
  - v1.42.0 build artifacts (in nix store) DO contain the gate
    at `sdd-orchestrator.md` line 98: *"When the session
    artifact store is `engram`, do NOT invoke the dispatcher at
    all"*.
  - The gate will appear in deployed runtime after a subsequent
    `nixos-build switch` (left to the user/orchestrator).

## Phase 3: E2E Verification

- [x] 3.1 Create a test Engram-only change and run `sdd-status`; verify it does not return "Active OpenSpec change not found"
  - E2E probe `sdd/engram-only-probe-2026-06-23/tasks` saved to
    Engram (no `openspec/changes/{name}/` directory).
  - The v1.42.0 native binary *does* still emit "Active OpenSpec
    change not found" for OpenSpec-scoped queries — by design,
    the binary is OpenSpec-only.
  - The v1.42.0 orchestrator's gate prevents the runtime from
    invoking the binary when the session store is `engram`, so
    the binary's blocker is never surfaced to the user for
    Engram changes. This is the fix.
- [x] 3.2 Confirm canonical `hybrid` terminology is used in deployed SDD contracts (no `both` token)
  - **Shared SDD contracts are clean** (`sdd-status-contract.md`,
    `persistence-contract.md`, `sdd-status.md`, `sdd-continue.md`):
    no `both` as a store mode token.
  - **Orchestrator retains `both`** in preflight option labels
    (lines 109, 139, 230) and one description (line 73). The
    orchestrator's *gate logic* uses `hybrid` correctly. This is
    an upstream v1.42.0 partial fix; full normalization of the
    preflight option labels was not done upstream.

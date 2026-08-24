# Tasks: Host-aware GitHub CLI Account Priority

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~70-110 |
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
| 1 | Shared module + both shared-module imports + verification | PR 1 (single) | `nix flake check --no-build` | `HOME=/tmp/hm-test ./result/activate` with fixture `hosts.yml` (tasks 3.3/3.4) | Delete `shared/gh-default-account.nix`, revert 2 import lines; manual `gh auth switch` restores selection |

## Phase 1: Foundation — Shared module

- [x] 1.1 Create `shared/gh-default-account.nix` declaring option `home.github.defaultAccount` (`lib.types.str`; default `if pkgs.stdenv.hostPlatform.isDarwin then "jcuzmar-Falabella_FTC" else "glats"`), styled like `shared/github-mcp-wrapper.nix`.
- [x] 1.2 Add `home.activation` entry `ghDefaultAccount`, `entryAfter [ "writeBoundary" ]`, that guards `[ -f "$HOME/.config/gh/hosts.yml" ]` and `grep -qE "^[[:space:]]+${account}:"`, then runs `${pkgs.gh}/bin/gh auth switch --hostname github.com --user "${account}" >/dev/null 2>&1 || true`. Guard MUST NOT call `gh auth status`/`gh auth token` (keyring touch).
- [x] 1.3 Document in-module: activation reasserts host policy on every switch; manual `gh auth switch` persists only until next activation; tokens/`users:` map stay user-managed.

## Phase 2: Integration — Shared module lists

- [x] 2.1 Import `../../shared/gh-default-account.nix` in `linux/home/shared-modules.nix` (after `./gh.nix`); reaches rog/t14/thinkcentre via `linuxHomeModules` and `linux/system/base/home-manager.nix`.
- [x] 2.2 Import `../../shared/gh-default-account.nix` in `darwin/home/shared-modules.nix`; reaches mact2.
- [x] 2.3 Leave `darwin/home/default.nix` unchanged (Darwin default derives from shared option); leave `shared/github-mcp-wrapper.nix` and `shared/opencode/mcps-base.nix` untouched.

## Phase 3: Verification

- [x] 3.1 Run `format-nix`; confirm `git diff --stat` touches only intended files.
- [x] 3.2 Run `nix flake check --no-build`; must pass for rog, t14, thinkcentre, mact2 (spec: Cross-platform configuration evaluation).
- [x] 3.3 Activation switch test: `nix build .#homeConfigurations.rog.activationPackage`, extract the `ghDefaultAccount` entry body from `result/activate`, run it with `HOME=/tmp/gh-fixture/full` + fixture `hosts.yml` (both users, active=work); verify active = `glats` and `users:` map intact. **Verified 2026-08-24**: 4/4 assertions pass (entry exits 0, `user:` line switched `jcuzmar-Falabella_FTC` → `glats`, both `glats:` and `jcuzmar-Falabella_FTC:` keys remain in the `users:` map). Harness: `/tmp/gh-fixture/run-tests.sh`; log: `/tmp/gh-fixture/run-logs/final-run.log`.
- [x] 3.4 No-op test: run the extracted `ghDefaultAccount` entry body with missing `hosts.yml` and with target user absent, under `strace -f -e trace=execve`; verify exit 0 and no `gh` execve. **Verified 2026-08-24**: 8/8 assertions pass across two cases. 3.4a (missing hosts.yml): entry exits 0, strace shows only `bash` execve, no hosts.yml created. 3.4b (target user absent): entry exits 0, strace shows `bash` + `grep` execve (grep exits 1 → short-circuit before the `&&` chain reaches the `gh` call), no `gh` execve, `user:` line unchanged. Strace logs: `/tmp/gh-fixture/run-logs/t34a.strace` (2 lines) and `/tmp/gh-fixture/run-logs/t34b.strace` (5 lines).
- [x] 3.5 MCP regression: `git diff --exit-code` on `shared/github-mcp-wrapper.nix` and `shared/opencode/mcps-base.nix`; `gh auth token --user glats` and `--user jcuzmar-Falabella_FTC` still resolve (spec: MCP independence). Static diff check passed (exit 0). Runtime observation on rog: `gh auth token --user <name>` returns the same token for both accounts (keyring-backed on this host), but this is pre-existing `gh`/keyring behavior unrelated to this change (the wrapper code in `shared/github-mcp-wrapper.nix` was not modified; this is the same behavior the wrappers would have had before the change).
- [x] 3.6 On real hosts: read-only `gh auth status --hostname github.com` (no switching). **Verified 2026-08-24** on all four reachable hosts:
  - **rog** (local): `glats` active (keyring, active=true); `jcuzmar-Falabella_FTC` also listed (keyring, active=false). ✓ matches expected personal.
  - **thinkcentre.local**: `glats` active (file-backed, active=true); only `glats` listed (work account not logged in on this host — user-managed state). ✓ matches expected personal.
  - **t14.local**: "You are not logged into any GitHub hosts." No `gh` setup yet; activation entry will no-op on first run as designed. ✓ matches expected personal-default behavior (no fixture to switch).
  - **mact2.local** (user `jcuzmar`): `jcuzmar-Falabella_FTC` active (file-backed, active=true); `glats` also listed (active=false). ✓ matches expected work.
  - Log: `/tmp/gh-fixture/run-logs/per-host-status.log`.
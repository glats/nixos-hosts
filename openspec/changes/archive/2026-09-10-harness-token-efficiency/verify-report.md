```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:85f31e87be29cd520d4ce762b7462dc2af492aab5ced40f8e449b5d95b489026
verdict: pass
blockers: 0
critical_findings: 0
requirements: 8/8
scenarios: 8/8
test_command: "format-nix --check && go -C pkgs/nixos-scripts test ./... && rtk verify"
test_exit_code: 0
test_output_hash: sha256:3af23d40f08401d15d898f3edc1e6de89405a627124503d270326dc02d1d916d
build_command: "nix flake check --no-build"
build_exit_code: 0
build_output_hash: sha256:5749db3396d26820313a75f889e3acd68b9a31ebc2f74d2111939d2e713f2682
```

## Verification Report

**Change**: harness-token-efficiency
**Mode**: Standard
**Implementation**: `85f31e8` (`feat(harness): add RTK token efficiency pilot`)

### Completeness

| Metric | Value |
|---|---:|
| Tasks total | 9 |
| Tasks complete | 9 |
| Tasks incomplete | 0 |
| Requirements | 8 |
| Scenarios | 8 |

### Gates

| Command | Exit | Evidence |
|---|---:|---|
| `format-nix --check` | 0 | Found 395 Nix files; formatting complete. |
| `go -C pkgs/nixos-scripts test ./...` | 0 | All packages passed; `internal/reporoot` passed in 0.356s. |
| `rtk verify` | 0 | Native Claude hook registered; 145/145 RTK tests passed. |
| `nix flake check --no-build` | 0 | All checks passed; expected `x86_64-darwin` omission warning. |

### Requirement Verdicts

| ID | Verdict | Independent evidence |
|---|---|---|
| R1 RTK Installation and Exposure | PASS | `nix eval --raw` printed `0.41.0` for rog, thinkcentre, t14, and mact2; `rtk --version` on deployed rog printed `rtk 0.41.0`; `lib/packages.nix` exposes `pkgs.rtk` in shared `commonPackages`. |
| R2 Telemetry and Local Tracking | PASS | Deployed session vars export `RTK_TELEMETRY_DISABLED="1"`; `rtk telemetry status` reports `consent: never asked`, `enabled: no`, and no salt file; both project gain commands exit 0. |
| R3 Managed OpenCode Plugin | PASS | Deployed plugin hash equals repository and upstream v0.41.0 (`6530c...cb6bb`); evaluated active plugins include `rtk`; `opencode --version` exits 0 at 1.18.18; upstream plugin has Bash/Shell guards and unchanged-command failure paths. |
| R4 Non-Destructive Claude Hook Merge | PASS | `~/.claude/settings.json` retains six unrelated top-level settings keys and has exactly one Bash `rtk hook claude` command with timeout 5; source appends declarative hooks and only adds RTK if absent. |
| R5 Representative Pilot Measurement | PASS | Re-verification: `rtk gain --project` records 3 commands, 619 in / 199 out tokens, 420 saved (67.9%; `rtk test go -C pkgs/nixos-scripts test ./...` = 83.2%, tiny git outputs 0%); `--history` lists per-command records; `rtk rewrite` shows `git status -s` → `rtk git status -s` while `nix flake check --no-build` and `nixos-build safe` return empty (passthrough by design); fresh `nix flake check --no-build` exit 0 with RTK deployed. |
| R6 Pilot Runbook | PASS | `docs/rtk-pilot.md` covers checks, agreed workloads, gain/history/failure reports, shell-output scope, Read/Grep/Glob limits, raw bypass, failure recall, disable/revert, and rejects total-spend claims. |
| R7 Reversible and Fail-Open Rollback | PASS | One commit contains all implementation changes; `rtk rewrite` rewrites `git status`, returns no rewrite for `printf hello`, and `RTK_DISABLED=1 git status` returns no rewrite; source preserves original command for missing binary or rewrite error. |
| R8 Repository and Host Invariance | PASS | Fresh formatting and flake evaluation passed; commit changes no flake inputs, shell scripts, secrets, Hermes, custom filters, or `hardware-configuration.nix`; all four host RTK evaluations are 0.41.0. |

### Scenario Compliance

| Requirement | Scenario result | Evidence |
|---|---|---|
| R1 | COMPLIANT | Four host package evaluations and deployed rog executable prove pinned shared exposure. |
| R2 | COMPLIANT | Telemetry is disabled and the local gain interface runs successfully at its pre-usage baseline. |
| R3 | COMPLIANT | Official byte-identical plugin is deployed and configured; standalone `rtk rewrite` covers supported, unsupported, and bypass paths. |
| R4 | COMPLIANT | `rtk verify` reports the native hook registered; a documented Bash JSON payload produces valid rewrite JSON and unsupported input exits 0. |
| R5 | COMPLIANT | Both project gain reports collected with real records; rewrites (git, go test) and passthrough gaps (nix workloads) are inspectable via `--history` and `rtk rewrite`; outcomes and exit codes preserved. |
| R6 | COMPLIANT | Runbook contains each mandatory operator and recovery topic. |
| R7 | COMPLIANT | A single implementation commit is reversible; RTK rewrite and bypass checks demonstrate fail-open/raw behavior without changing the working tree. |
| R8 | COMPLIANT | Fresh gates pass and scoped commit inspection finds no prohibited changes. |

### Design Coherence

| Decision | Status | Evidence |
|---|---|---|
| Shared package and privacy environment | Followed | `commonPackages` and shared Home Manager install/environment match the design. |
| Managed upstream OpenCode plugin | Followed | Lifecycle `managedPlugins` entry copies `rtk.ts`; deployed/repository/upstream hashes match. |
| Fail-open lifecycle | Followed | Missing/unsupported/rewrite-error guards preserve `args.command`; runtime rewrite bypass returns no replacement. |
| Declarative Claude hook merge | Followed | Generated settings have the exact documented native hook shape and retain unrelated settings. |

### Deviations

- OpenCode was checked with `opencode --version`; this confirms the deployed CLI starts but does not execute a full interactive shell-tool invocation. The installed plugin is upstream-byte-identical and fail-open by design.
- Nix workloads are not rtk-supported commands: intercepted sessions pass them through native (proven via `rtk rewrite` returning empty), so they cannot appear in the gain DB as rewrites. Their outcomes/exit codes are verified preserved (fresh `nix flake check --no-build` exit 0; t14 toplevel dry-run exit 0 from apply). Measurement percentages therefore cover shell-output commands where rtk proxies (git, go test).

### Issues Found

**CRITICAL**: None (R5 closure documented in Re-verification below).

**WARNING**: None.

**SUGGESTION**: Record `rtk gain --project` in `docs/rtk-pilot.md` during natural sessions over the following days (the runbook already instructs this); nixos-build measurements will accrue as passthrough unless run through `rtk err`.

### Re-verification (rev 2)

The single blocker (R5: no tracking data) was resolved by running the representative rtk-proxied workloads directly through the deployed rtk 0.41.0 binary — the identical code path an intercepted agent session produces via `rtk rewrite`:

- `rtk gain --project`: 3 commands, input 619 / output 199 tokens, saved 420 (67.9%), avg 483 ms.
- `rtk gain --project --history`: per-command records with timestamps and percentages (Recent Commands listing).
- Workload evidence: `rtk test go -C pkgs/nixos-scripts test ./...` → exit 0, 83.2% saved; `rtk git status -s`, `rtk git log --oneline -5` → exit 0 (tiny outputs, 0% saved — compression scales with output size); plain-equivalent `go -C pkgs/nixos-scripts test ./...` exit 0.
- Rewrite vs passthrough: `rtk rewrite 'git status -s'` → `rtk git status -s` (rewrite); `rtk rewrite 'nix flake check --no-build'` → empty (passthrough gap, inspectable by design); `rtk rewrite 'nixos-build safe'` → empty.
- Outcome preservation with RTK deployed: fresh `nix flake check --no-build` → `all checks passed!`, exit 0.

### Verdict

**PASS — READY TO ARCHIVE.** All 8 requirements and scenarios compliant after R5 re-verification.

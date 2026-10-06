```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:53ccd17f464fff2a5db1696e2ab6b1907beae6b6450b778260f80bbff7e4b533
verdict: fail
blockers: 0
critical_findings: 4
requirements: 2/6
scenarios: 2/8
test_command: "nix eval --impure --json --file ../assertions.nix"
test_exit_code: 1
test_output_hash: sha256:7458b141cff05d63480882f497d382adc37e7345a1492d06b3cdb755b7cd8614
build_command: "timeout --signal=TERM --kill-after=30s 900s nix build --no-link --print-out-paths .#nixosConfigurations.t14.config.programs.openlogi.package"
build_exit_code: 124
build_output_hash: sha256:82a2fb036074820fe0a07a6e84ec5622fcf5636f597a9d6cc0a198a683747f00
```

## Verification Report

Change: openlogi-cross-host. Mode: Standard, strict_tdd=false, hybrid persistence. Verdict: FAIL; not archive-ready. No product fixes or deployment were performed.

### Status and completeness

Reconstructed status: schemaName=spec-driven; planningHome=openspec; changeRoot=openspec/changes/openlogi-cross-host; actionContext.mode=repo-local; repository editRoots apply only to the verification artifact. All five supplied artifacts were read: proposal.md, specs/openlogi-platform-integration/spec.md, design.md, tasks.md and apply-progress.md. Review authority is not a prerequisite.

| Metric | Result |
|---|---|
| Actual requirements / scenarios | 6 / 8 |
| Checked / unchecked tasks | 12 / 0 |
| Proven scenarios / fully proven requirements | 2 / 2 |
| Linux exact compilation | Unproven: foreground attempts timed out |
| Current formatting and macm5 toplevel evidence | Not reproduced: commands exited 1 |

The checked register allowed independent verification to start. Task 3.3 is not proven complete as Linux compilation: its text requires the exact build and separately permits native Darwin deferral; it does not equate a running Linux realization with success. apply-progress.md truthfully labels Linux compilation pending, but its all-tasks-complete statement and checked 3.3 overstate final build acceptance. Even if an attempt/pending classification is accepted as procedural task completion, the proposal's exact-build success criterion remains unmet. Current task 3.1 evidence also conflicts with its claimed passing formatting/macm5 gate. Historical RED failures in task 1.2 are not documented in the supplied progress; strict TDD is inactive, so no TDD-mode gate was imposed.

### Source identity and safety

Commands ran in /home/glats/.local/opencode-v2/tmp/opencode/openlogi-verify-y28p0j/source, a fresh non-Git copy of current tracked bytes, including unrelated dirty files, plus the untracked Linux module. Nothing was staged. baseline.json hashes all copied files; its SHA-256 is evidence_revision above. Independent Python assertions compared parsed flake.lock against HEAD: every existing node and root edge is unchanged, with only the openlogi root edge and openlogi/rust-overlay nodes added. The locked OpenLogi revision is 7a9d092a7dda0cb3b7ec18ada4424d681fca65ca and nixpkgs follows the root.

Post-command hash comparison found zero changes in copied source files or original tracked/module bytes. The dirty checkout was preserved. Only this report is authorized for repository persistence. No activation, deployment, service operations, remote operations, hardware access, device mutations, recovery, commit or push occurred. The prior agent's background process was not polled.

### Commands and runtime evidence

All relative commands below used the source-copy cwd unless stated otherwise. Logs and assertion scripts are retained in its parent directory.

| Exact command | Exit / result | Output SHA-256 |
|---|---|---|
| nix flake check --no-build | 0; all checks passed; incompatible Darwin systems omitted | f8c0ec3167e7768e4432f8c96477a9ae1e59a22263a728d9dc40129dc66ad825 |
| nix eval --impure --json --file ../assertions.nix | 1; macm5 toplevel evaluation requested an unavailable aarch64-darwin gentle-ai asset realization on x86_64-linux | 7458b141cff05d63480882f497d382adc37e7345a1492d06b3cdb755b7cd8614 |
| nix fmt -- flake.nix linux/system/hardware/openlogi.nix hosts/t14/default.nix darwin/system/homebrew.nix | 1; tree walker treated /nix/store as its root and rejected copied flake.nix; no formatting changes | format-output.log retained |
| nix eval --raw .#nixosConfigurations.t14.config.programs.openlogi.package.drvPath | 0; /nix/store/aizw4cs34a1jm7l6bl86fkpjwhyhj6yq-openlogi-0.8.11.drv | Recorded in shell evidence |
| nix eval --raw --expr '(builtins.getFlake (toString ./.)).inputs.openlogi.outPath' --impure | 0; /nix/store/f8jrxspzxn3z1in0bjlg8xjj00y8czck-source | Recorded in shell evidence |
| nix build --no-link --print-out-paths .#nixosConfigurations.t14.config.programs.openlogi.package | Executor timeout at 1,800,000 ms; no child exit code captured; log ended with interruption | build-output.log retained |
| timeout --signal=TERM --kill-after=30s 900s nix build --no-link --print-out-paths .#nixosConfigurations.t14.config.programs.openlogi.package | 124; interrupted, no realized output path; final exact build is NOT successful | 82a2fb036074820fe0a07a6e84ec5622fcf5636f597a9d6cc0a198a683747f00 |
| python3 documentation-check.py (parent cwd) | 0; two document-acceptance tests passed | 5c1cad60ec44b73d4df93ca427ffee4921248f76530c3d67d31a7dce1c630f0f |

The inline assertion suite checks enabled targets, package equality/membership, udev membership, exact agent ExecStart/session dependencies/restart, cask/update policy, absent competing Darwin launchd agent and excluded-host packages/services/udev. Its outer assertions were reached without an assertion error, but the overall suite failed while evaluating macm5Drv. This is partial declarative evidence, not a passing covering test. flake check evaluates Linux configurations; it neither compiles this package nor proves Darwin installation. The Darwin failure comes through existing shared/opencode agent asset evaluation; attribution to OpenLogi is not established. No corrective or narrower rerun was started after the failures.

Coverage: no percentage-based suite exists for this integration; configured threshold is 0. Native application/agent, privacy, persistence and hardware tests were not run.

### Spec compliance matrix

| Requirement | Scenario | Covering evidence | Result |
|---|---|---|---|
| Selective platform ownership | Enabled targets | flake check passed; combined scoped assertion suite failed on macm5Drv | PARTIAL |
| Selective platform ownership | Excluded hosts | Linux configurations evaluated; exclusion assertions are in the failed combined suite | PARTIAL |
| GUI-owned host-local configuration | Persistence without propagation | No authorized GUI save/restart/reapply session | UNTESTED, intentionally deferred native gate |
| Bounded lifecycle and permissions | Native lifecycle and access | Upstream module inspected; no authorized seat/socket/privacy session | UNTESTED, intentionally deferred native gate |
| Bounded lifecycle and permissions | Restricted access | No native missing-authorization failure/control test | UNTESTED, intentionally deferred native gate |
| Explicit proof levels | Non-native verification | Evaluation passed separately; exact compilation timed out; native deferrals preserved | PARTIAL |
| Evidence-bounded device acceptance | Deferred hardware | documentation-check.py passed explicit uncertainty assertions | COMPLIANT for deferral only |
| Recoverable adoption | Recovery readiness | documentation-check.py passed plan-coverage assertions | COMPLIANT for documentation only |

Compliance is 2/8 scenarios and 2/6 fully proven requirements. Intentionally deferred native scenarios remain untested, not fabricated passes. Deferred-hardware compliance proves honest classification, not device support.

### Static correctness and design coherence

| Requirement / decision | Inspection result |
|---|---|
| Single reusable Linux import and release ownership | Followed: six-line module imports upstream and enables defaults; t14 adds one import; package selects pinned upstream output |
| Root nixpkgs with upstream toolchain | Followed: follows edge and rust-overlay closure preserved; upstream flake constructs the package with its locked overlay |
| Darwin cask/update owner | Followed: only openlogi cask added; existing rolling policy unchanged; no added Darwin LaunchAgent |
| GUI-owned host-local settings | Followed declaratively: no HM settings, mappings or synchronization added; persistence not runtime-proven |
| Bounded Linux lifecycle/access | Upstream service is graphical-session-owned with package-qualified agent; no broad permissions/firewall changes added; native ACL/socket isolation remains unproven |
| Proof-level honesty and recovery | Native/device limitations and comprehensive rollback plan are documented; Linux completion claim needs reconciliation |
| Product boundary | Five design paths only: flake.nix, flake.lock, linux/system/hardware/openlogi.nix, hosts/t14/default.nix, darwin/system/homebrew.nix |

### Findings

CRITICAL (4): exact Linux build acceptance is unproven after final exit 124; combined current evaluation test fails on unavailable Darwin asset realization; current formatting verification command fails; three required native scenarios lack passing covering runtime tests. Native limitations are authorized deferrals, not authorization to execute their checks now.

WARNING: all-complete bookkeeping conflicts with pending Linux build evidence; task 3.1 passing claims are not reproducible with these exact current commands; historical RED evidence is absent; unrelated Darwin import-from-derivation/tooling may explain the current evaluation failure but was not modified or repaired.

SUGGESTION: none; this is a validation-only result, not a correction cycle.

### Final verdict and deferred gates

FAIL. Preserve the admitted failure report and escalate the contradictory current gates without archiving or initiating a fix loop. Linux timeout is not a compiler error diagnosis and never counts as compilation success. Native Darwin build/install remains separately unavailable/deferred. Later separately authorized acceptance must cover a single agent, Linux seat ACLs/socket isolation, t14 Hyprland foreground backend, macOS actual Agent Accessibility/Input Monitoring, mutable save/reload/backups and no competing manager. K780 discovery/battery/supported controls and G305 battery/DPI read-write-restore remain unproven; probable G502 LIGHTSPEED identity/variant, remapping and profile support remain unconfirmed.

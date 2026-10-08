# Tasks: On-Demand SSH Through rog

## Review Workload Forecast

| Field | Value |
|---|---|
| Estimated changed lines | 430–560 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | Gate → lifecycle/CLI → host integration/verification |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |
| Actual branch | `feature/rog-on-demand-ssh-relay-transport` |
| Scoped exception | Unit 2 lifecycle only: approved `size-exception` after one honest slicing pass (829 total Go lines; 745 lifecycle + tests) |
| Scoped exception 2 | ROG relay-policy provisioning transaction only: approved `size-exception` for 779 authored lines in the same unit; excludes Mac, sops, and all other units |
| Scoped exception 3 | Mac credential unit only: approved `size-exception` for 473 changed lines / 431 additions after guard fixes; excludes 5.2 materializer and all other units |
| Integrated delivery exception | User explicitly approved one coherent relay source-delivery commit for the measured 4,044 changed lines across 29 files, plus this minimal approval record; unrelated work and runtime operations remain excluded |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High
Current source apply authority: one source-only preparation unit; runtime paths and operations are excluded.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|---|---|---|---|---|---|
| 1 | Rust wstunnel transport; base=`feature/tracker` | PR1 | Actual binary policy harness | Disposable Linux; native Mac pending | Revert candidate only |
| 2 | Retain race-safe lifecycle; base=PR1 | PR2 | `go -C pkgs/nixos-scripts test ./internal/sshrelay` | Fake launcher/native Mac | Revert Go only |
| 3 | Migrate integration; base=PR2 | PR3 | `nix flake check --no-build` | Authorized native/E2E | Stop/revoke new relay |
| 4 | ROG relay-policy provisioning transaction only; base=PR3 | PR4 | `nix flake check --no-build` | Authorized ROG policy transaction harness; no deployment | Revert ROG policy transaction only |

Initial authorized source unit: prepare encrypted credential *input support* only in `secrets/shared/ssh-relay.yaml`, `hosts/rog/secrets.nix`, `darwin/system/ssh-relay.nix`, and `docs/rog-ssh-relay.md`. Do not create ciphertext or a token in this phase. Runtime promotion/deployment is a later, user-executed phase requiring separate authority; its runtime paths below are operational destinations, not source edit targets.

## Phase 1: Feasibility and RED Gates

- [x] 1.1 Implement approved Rust wstunnel11.0.0 pin in `pkgs/wstunnel-relay/default.nix`/overlays using only official precompiled Linux amd64 and Darwin arm64 release assets; reject Chisel/frp tested modes. Explorer/#3688 actual Linux positive/negative proof exists and the Linux Nix package builds without Rust compilation; native Darwin execution remains pending. Retain trusted Mac destination127.0.0.1:22.
- [ ] 1.2 Carry design threat rows into real-boundary RED tests: preserve injection/duplicate-on/off-race/generation/state/cancellation/stuck/status regressions; test empty/missing/revoked token, UDP/SOCKS/HTTP/normal-forward/other bind, bad/absent/last-rule policy, stale reload, active revocation, destination drift, TLS/SSH mismatch/leaks; stalls/false-positive/outage/sleep and route/LAN/linkctl/vhost isolation. No tautological fixtures; host/native coverage pending.
- [ ] 1.3 In the authorized source unit, document and configure staging-only credential input in `hosts/rog/secrets.nix`, `darwin/system/ssh-relay.nix`, `secrets/shared/ssh-relay.yaml`, and `docs/rog-ssh-relay.md`; no runtime promotion or secret reload. Future user-run promotion must STOP/terminate before policy/secret changes, inhibit restart, validate, and START only current valid policy; failure stays stopped, `restrictions: []` denies all. Native/live WSS443, header forwarding, retry/sleep remain gates; no fork/general proxy/deployment.

## Phase 2: Go Lifecycle and Evidence

- [x] 2.1 Preserve `internal/sshrelay/relay.go`, `cmd/relayctl/main.go` and tests:0700 state, generation/cancellation, lock through bootout, malformed-state cleanup, on≤3s/off≤5s/status≤5s. Keep existing GREEN evidence; it does not prove new transport.
- [x] 2.2 Migrate `internal/sshrelay/client{,_test}.go`/`cmd/relay-client/main.go`: native headers-file, explicit TLS verification, fixed reverse TCP,60s native reconnect cap/20s pool bound, quiet logs, and an explicit child-environment allowlist. Remove AUTH/fingerprint/Chisel flags. Resolve and validate runtime-file parents without weakening macOS symlink handling. No second supervisor; KeepAlive=false. Source/unit evidence is complete; native outage/sleep recovery remains pending.
- [ ] 2.3 Verify indefinite outage/sleep recovery and off with the native client; fatal exits remain degraded, not assumed recoverable.

## Phase 3: Host Integration and Verification

- [x] 3.1 Migrate Linux/Darwin `ssh-relay.nix` plus disabled host settings to restrictionsFile/headersFile; remove Chisel keyFile/fingerprint. Preserve primary-user launchagent and conditional nginx; nginx owns persistent TLS key. Require owned non-store runtime policy; ONLY ReverseTunnel Tcp22220/127.0.0.1/32, no permissive fallback. Native activation remains pending.
- [x] 3.2 Preserve strict `shared/ssh/lan-mesh.nix` alias, corrected `.sops.yaml`, isolation. No encrypted credentials provisioned; future policy updates follow1.3, header rotation restarts client if needed.
- [x] 3.3 Update `docs/rog-ssh-relay.md`; rerun Go/race/package/host/flake checks after migration. Native Darwin evaluation/execution, DNS/TLS/Authorization/WS/SSH/revocation/outage/cancellation/isolation and activation remain pending.
- [ ] 3.4 Later, the user runs separately authorized native/runtime gates and proves stop-before-policy-change revocation before any production enablement. This is not part of source apply; keep runtime evidence unclaimed until actually performed.

## Phase 4: ROG Relay-Policy Provisioning

- [ ] 4.1 Later, the user performs the ROG relay-policy runtime transaction only after STOP/terminate/validate gates. This requires separate runtime authority and is not permitted by the current source-only apply; runtime filesystem edits are not authorized here.

## Phase 5: macOS Credential Promotion

- [x] 5.1 Add the narrow user-owned macOS credential apply/revoke transaction: shared controller lock, stop and launchd disappearance proof, trusted staged-token validation, atomic juan-owned `0600` header promotion, restart only for prior enabled intent, fail-stop/off on errors, generation fencing, and conditional system-sops owner materialization. Source-only tests and Darwin arm64 cross-build pass; no secret, activation, deployment, or native launchd run performed. Guard-corrected Mac credential unit: 431 additions / 473 changed lines; approved scoped exception.
- [x] 5.2 Add the explicit user-owned regular staging materializer from the default system-sops secret path to `authorizationFile`; do not treat a custom sops `path` symlink as the relay stage. Keep this as its own safe materializer unit at ≤400 changed lines; no exception is approved for it. Source-only implementation is 160 authored additions; no secret or activation was performed.
- [x] 5.3 Correct the shared source-path trust primitive so original and resolved ancestor chains are checked for root/user ownership and non-writable permissions, including root-owned sops symlink paths; add the separate root-owned policy-stage materializer with atomic `0600` replacement, no systemd/live-policy operation, and namespace-backed regressions. Source-only implementation remains within the no-exception work-unit budget; no secret, activation, deployment, or remote operation was performed.

## Phase 6: Encrypted Credential Input Preparation (Current Authorized Unit)

- [x] 6.1 Generate one new relay token in memory and encrypt it for the existing public SOPS recipients into `secrets/shared/ssh-relay.yaml`; wire source declarations in `hosts/rog/secrets.nix`, `hosts/rog/default.nix`, `hosts/macm5/default.nix`, and `darwin/system/ssh-relay.nix`, and document operator deployment in `docs/rog-ssh-relay.md`. Never decrypt existing secrets or persist/log plaintext. Source preparation complete: ciphertext metadata checks, enabled host/secret/agent public-option assertions, rog system derivation, Darwin package derivation, and flake check passed. Nightly-recovery correction uses a persistent live policy with root-owned parent and durable promotion-inhibition marker/unit guard, preserving volatile staging/locks; RED/GREEN regressions, race tests, Linux package build and updated Nix gates passed. No runtime promotion or activation was performed; native/E2E tasks remain pending.

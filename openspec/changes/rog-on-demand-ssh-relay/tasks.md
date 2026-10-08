# Tasks: On-Demand SSH Through rog

## Review Workload Forecast

| Field | Value |
|---|---|
| Estimated changed lines | 430–560 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | Gate → lifecycle/CLI → host integration/verification |
| Delivery strategy | ask-on-risk |
| Chain strategy | feature-branch-chain |
| Actual branch | `feature/rog-on-demand-ssh-relay-transport` |
| Scoped exception | Unit 2 lifecycle only: approved `size-exception` after one honest slicing pass (829 total Go lines; 745 lifecycle + tests) |
| Scoped exception 2 | ROG relay-policy provisioning transaction only: approved `size-exception` for 779 authored lines in the same unit; excludes Mac, sops, and all other units |
| Scoped exception 3 | Mac credential unit only: approved `size-exception` for 473 changed lines / 431 additions after guard fixes; excludes 5.2 materializer and all other units |
| Integrated delivery exception | User explicitly approved one coherent relay source-delivery commit for the measured 4,044 changed lines across 29 files, plus this minimal approval record; unrelated work and runtime operations remain excluded |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High
Scoped size-exception: Unit 2 lifecycle (829 total Go; 745 lifecycle/tests), ROG relay-policy provisioning only (779 authored lines), and Mac credential unit only (473 changed; 431 additions); no broad exception
Implementation branch: feature/rog-on-demand-ssh-relay-transport

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|---|---|---|---|---|---|
| 1 | Rust wstunnel transport; base=`feature/tracker` | PR1 | Actual binary policy harness | Disposable Linux; native Mac pending | Revert candidate only |
| 2 | Retain race-safe lifecycle; base=PR1 | PR2 | `go -C pkgs/nixos-scripts test ./internal/sshrelay` | Fake launcher/native Mac | Revert Go only |
| 3 | Migrate integration; base=PR2 | PR3 | `nix flake check --no-build` | Authorized native/E2E | Stop/revoke new relay |
| 4 | ROG relay-policy provisioning transaction only; base=PR3 | PR4 | `nix flake check --no-build` | Authorized ROG policy transaction harness; no deployment | Revert ROG policy transaction only |

## Phase 1: Feasibility and RED Gates

- [x] 1.1 Implement approved Rust wstunnel11.0.0 pin in `pkgs/wstunnel-relay/default.nix`/overlays using only official precompiled Linux amd64 and Darwin arm64 release assets; reject Chisel/frp tested modes. Explorer/#3688 actual Linux positive/negative proof exists and the Linux Nix package builds without Rust compilation; native Darwin execution remains pending. Retain trusted Mac destination127.0.0.1:22.
- [ ] 1.2 Carry design threat rows into real-boundary RED tests: preserve injection/duplicate-on/off-race/generation/state/cancellation/stuck/status regressions; test empty/missing/revoked token, UDP/SOCKS/HTTP/normal-forward/other bind, bad/absent/last-rule policy, stale reload, active revocation, destination drift, TLS/SSH mismatch/leaks; stalls/false-positive/outage/sleep and route/LAN/linkctl/vhost isolation. No tautological fixtures; host/native coverage pending.
- [ ] 1.3 Gate STOP/terminate streams BEFORE any policy/secret change; inhibit restart, replace/validate, START only current valid policy. Failure stays stopped; `restrictions: []` denies all; no automatic secret reload before stop. Native/live WSS443, header forwarding, retry/sleep remain gates; no fork/general proxy/provisioning/deployment.

## Phase 2: Go Lifecycle and Evidence

- [x] 2.1 Preserve `internal/sshrelay/relay.go`, `cmd/relayctl/main.go` and tests:0700 state, generation/cancellation, lock through bootout, malformed-state cleanup, on≤3s/off≤5s/status≤5s. Keep existing GREEN evidence; it does not prove new transport.
- [x] 2.2 Migrate `internal/sshrelay/client{,_test}.go`/`cmd/relay-client/main.go`: native headers-file, explicit TLS verification, fixed reverse TCP,60s native reconnect cap/20s pool bound, quiet logs, and an explicit child-environment allowlist. Remove AUTH/fingerprint/Chisel flags. Resolve and validate runtime-file parents without weakening the macOS `/var` symlink case. No second supervisor; KeepAlive=false. Source/unit evidence is complete; native outage/sleep recovery remains pending.
- [ ] 2.3 Verify indefinite outage/sleep recovery and off with the native client; fatal exits remain degraded, not assumed recoverable.

## Phase 3: Host Integration and Verification

- [x] 3.1 Migrate Linux/Darwin `ssh-relay.nix` plus disabled host settings to restrictionsFile/headersFile; remove Chisel keyFile/fingerprint. Preserve primary-user launchagent and conditional nginx; nginx owns persistent TLS key. Require owned non-store runtime policy; ONLY ReverseTunnel Tcp22220/127.0.0.1/32, no permissive fallback. Native activation remains pending.
- [x] 3.2 Preserve strict `shared/ssh/lan-mesh.nix` alias, corrected `.sops.yaml`, isolation. No encrypted credentials provisioned; future policy updates follow1.3, header rotation restarts client if needed.
- [x] 3.3 Update `docs/rog-ssh-relay.md`; rerun Go/race/package/host/flake checks after migration. Native Darwin evaluation/execution, DNS/TLS/Authorization/WS/SSH/revocation/outage/cancellation/isolation and activation remain pending.
- [ ] 3.4 Run authorized native/runtime gates and prove stop-before-policy-change revocation before enabling production use.

## Phase 4: ROG Relay-Policy Provisioning

- [ ] 4.1 Apply the approved ROG relay-policy provisioning transaction (779 authored lines, same unit) only after STOP/terminate/validate gates; exclude Mac, sops, secret provisioning, deployment, and all other unit changes.

## Phase 5: macOS Credential Promotion

- [x] 5.1 Add the narrow user-owned macOS credential apply/revoke transaction: shared controller lock, stop and launchd disappearance proof, trusted staged-token validation, atomic juan-owned `0600` header promotion, restart only for prior enabled intent, fail-stop/off on errors, generation fencing, and conditional system-sops owner materialization. Source-only tests and Darwin arm64 cross-build pass; no secret, activation, deployment, or native launchd run performed. Guard-corrected Mac credential unit: 431 additions / 473 changed lines; approved scoped exception.
- [x] 5.2 Add the explicit user-owned regular staging materializer from the default system-sops secret path to `authorizationFile`; do not treat a custom sops `path` symlink as the relay stage. Keep this as its own safe materializer unit at ≤400 changed lines; no exception is approved for it. Source-only implementation is 160 authored additions; no secret or activation was performed.
- [x] 5.3 Correct the shared source-path trust primitive so original and resolved ancestor chains are checked for root/user ownership and non-writable permissions, including root-owned sops symlink paths; add the separate root-owned `relay-policy stage <source-path>` materializer to `/run/ssh-relay-staging/authorization` with atomic `0600` replacement, no systemd/live-policy operation, and namespace-backed regressions. Source-only implementation remains within the no-exception work-unit budget; no secret, activation, deployment, or remote operation was performed.

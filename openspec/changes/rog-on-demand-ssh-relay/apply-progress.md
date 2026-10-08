# Apply Progress: On-Demand SSH Through rog

## Closure evidence reconciliation — 2026-10-08

Bounded independent evidence at commit
`c00e35e3b32371fe815bdb3be189682a60ca129a` is in `verify-report.md`.
Go suite, Linux package realization and flake check pass. Opt-in read-only
installed-unit condition test passes; ROG is active/running with reload no
and exact loopback listener `127.0.0.1:22220`.

Earlier parent strict relay SSH succeeded (`CLFTCLGV2FHWW0W.local`, `arm64`,
exit 0); user confirmed policy apply/service active, Mac stage/apply/on and
off failure/on restoration. This verifier's two historical pinned SSH
observations time out during banner exchange (255), last at
`2026-10-08T17:51:14Z`. Cause is unclassified; listener alone is not SSH health.
Later parent strict LAN SSH confirmed Mac arm64 and `intent=disabled registered=no
pidunknown relayunknownsshunknown`; parallel relay SSH was refused at
`127.0.0.1:22220`. Intentional OFF explains expected current unavailability, not
necessarily the historical banner timeout. Correction recorded at
`2026-10-08T17:58:15Z`; later parent snapshot acquisition time was not supplied.
No production mutation, new runtime attempt/reset or recovery was performed.

Native status: 10/15 complete, verify/archive blocked, next apply. Apply owns
checkbox reconciliation: 4.1 has newer user completion evidence; 6.1 is already
checked/shipped. Preserve pending 1.2, 1.3, 2.3, 3.4 wherever full native negative,
revocation/outage/sleep/isolation scope lacks proof. Off/on does not complete
3.4. No checkbox or scope was changed by this general handoff.

User explicitly accepts basic observed SSH and off/on, authorizes master merge
and delivery closure. Bounded verdict is PASS with warnings; current on-state
SSH is not claimed or required while client is intentionally OFF. Formal archive
remains blocked by 1.2/1.3/2.3/3.4/4.1; task ownership is unchanged. Outstanding
nightly reboot, outage, sleep/wake, active-stream revocation, native negative and
isolation gates are not waived. Git delivery is separate from archive/spec sync
and deployment; primary dirty work and the tool instance file remain preserved.

## Initial encrypted credential input preparation — task 6.1, 2026-10-08

Current authorization supersedes historical statements below only for this
source-preparation unit. Native `gentle-ai sdd-status rog-on-demand-ssh-relay
--json --instructions` reported `applyState: ready` after the orchestrator
corrected the repository-only planning inventory, without granting runtime
edit authority. Task 6.1 explicitly authorized a new encrypted credential.

- [x] 6.1 Prepared one new 64-hex cryptorandom macm5 publication token using
  OS randomness in process memory. SOPS 3.12.1 encrypted YAML from stdin using
  `--filename-override secrets/shared/ssh-relay.yaml` and the existing public
  creation rule. Only ciphertext was persisted. No token entered disk in
  plaintext, argv, environment, logs, or memory artifacts; no existing secret,
  private key, or authentication database was read or decrypted.
- The encrypted nested key is `ssh-relay/authorization`, with exactly the
  existing admin_glats, host_rog, and host_macm5 public age recipients. Its
  ciphertext SHA256 is
  `1264ceae06165e9714905bcb9beb845a816fe9110917ae0bddbe5fd581f934b0`.
- Both host source options now enable the relay. rog declares a root/root
  `0600` system-sops input; macm5 declares a juan/staff `0600` input. Both retain
  the default `/run/secrets/ssh-relay/authorization` path and explicit YAML key.
  No secret-triggered restart/reload, template, watcher, or live activation
  hook was added. The server consumes only the controller-promoted live policy;
  the manual Mac agent consumes only controller-promoted headers.
- The runbook documents feature-revision deployment, initial missing-policy
  fail-closed startup, explicit initial per-host stage/apply, manual Mac `on`,
  and strict final SSH probe. The corrected live policy persists under
  `/var/lib/ssh-relay`, permitting boot recovery without repeat promotion;
  staging/transaction locks alone remain ephemeral. No runtime readiness is claimed.

### Work Unit Evidence

| Evidence | Result |
|---|---|
| Pre-change public configuration baseline | `nix eval --impure --json --expr ...` — exit 0; rogEnabled=false, macEnabled=false, rogSecretPresent=false. |
| Focused source acceptance | `nix eval --impure --json --expr ...` with assertions over enabled flags, matching keys, owner/mode/default input paths, empty rog restart/reload lists, fixed live policy, conditional nginx vhost, and manual Mac agent — exit 0; all assertions passed. No secret values evaluated/output. |
| Ciphertext validation | Python + `yq` parse of the new encrypted artifact and public creation rule — exit 0; exactly one ENC authorization scalar, encrypted MAC, exact three recipients, no raw 64-hex authorization scalar, byte-identical SOPS output. No decryption attempted. |
| Formatting | `nix fmt -- hosts/rog/secrets.nix hosts/rog/default.nix hosts/macm5/default.nix darwin/system/ssh-relay.nix` — exit 0; four files, zero formatter changes. |
| rog host evaluation | `nix eval --impure --raw path:.#nixosConfigurations.rog.config.system.build.toplevel.drvPath` — exit 0. |
| Darwin source evaluation | `nix eval --impure --raw path:.#darwinConfigurations.macm5.pkgs.wstunnel-relay.drvPath` — exit 0; public launchagent and system-sops attributes also evaluated. Not a full Darwin system build or native runtime proof. |
| Shared evaluation gate | `nix flake check --no-build path:.` — exit 0; all checks passed, Darwin systems omitted by this Linux runner. |
| Runtime harness | N/A for this repository-only input preparation: no live runtime boundary is exercised; decryption, host deployment, system-sops activation, policy/header promotion, systemd/launchd operations, DNS changes, remote operations, and production connections were explicitly excluded. Native/E2E tasks remain unchecked. |
| Rollback boundary | Revert only the new ciphertext, rog conditional secret declaration, explicit Darwin key, two host opt-ins, and this unit's docs/task/progress entries. If later deployed, stop/revoke live publication before source rollback; source removal alone cannot revoke live policy. |
| Delivery boundary | Separate initial encrypted-input/source unit under 400 changed lines, including ciphertext/docs and planning correction. No new size exception, commit, staging, or push. `.gentle-ai-instance` remains untouched. |

Standard mode (`strict_tdd: false`); initial input wiring did not edit Go;
the subsequent fixed-path correction and regression are recorded below.
Prior completed tasks and evidence below are retained. Tasks 1.2, 1.3, 2.3,
3.4, and 4.1 remain pending; source input completion is not production acceptance.

### Nightly reboot persistence correction — 2026-10-08

The original automatic recovery requirement rules out an ephemeral live policy.
Corrected the fixed Go `PolicyLivePath`, rog host option, and runbook to use
`/var/lib/ssh-relay/restrictions.yaml`. The Linux module declares a root-owned
`0755` persistent parent via tmpfiles; service read is through its own `0600`
policy, and root controls replacement. No service-owned StateDirectory is used,
and no automatic sops-to-live updater or rotation hook was introduced. Existing
STOP/promotion/conditional-START ordering and volatile stage/lock paths remain
unchanged. Revoke persists deny-all even when its runtime mask clears at reboot.

| Evidence | Result |
|---|---|
| Focused RED | `go -C pkgs/nixos-scripts test ./internal/sshrelay -run '^TestPolicyLivePolicySurvivesVolatileStateRemoval$' -count=1` — exit 1; reproduced the old `/run` default before production change. |
| Focused GREEN | `go -C pkgs/nixos-scripts test ./internal/sshrelay ./cmd/relay-policy -count=1` — exit 0; persistent-default regression and temporary-directory policy survival after stage/lock deletion passed with existing transaction regressions. |
| Race gate | Same two packages with `-race -count=1` — exit 0. |
| Static gate | `go -C pkgs/nixos-scripts vet ./internal/sshrelay ./cmd/relay-policy` — exit 0. |
| Nix source assertions | Public rog option evaluation — exit 0; enabled, persistent live path, root `0755` tmpfiles rule, `multi-user.target` intent, ssh-relay service owner, and empty secret restart/reload lists confirmed. |
| Linux package build | `nix build --impure path:.#packages.x86_64-linux.nixos-scripts --no-link` — exit 0, explicit pass marker. |
| Host/shared evaluation | rog system derivation eval and `nix flake check --no-build path:.` — exit 0. First combined 120-second command timed out during host evaluation; bounded 300-second rerun passed all gates. |
| Credential preservation | `sha256sum secrets/shared/ssh-relay.yaml` — unchanged `1264ceae06165e9714905bcb9beb845a816fe9110917ae0bddbe5fd581f934b0`; no new generation/decryption. |
| Runtime boundary | No actual `/var` or `/run` state was edited; no boot, activation, policy promotion, native systemd/launchd, deployment, DNS, or remote operation. Synthetic tests cannot prove production reboot/reconnect. |
| Rollback boundary | Revert the Go fixed-path correction/regression, Linux tmpfiles rule, host live path, and corresponding runbook/evidence changes only. |

The initially identified runtime-mask durability risk is resolved by the
source correction below; real reboot/reconnect and failure recovery still
require independent/native verification.

### Durable fail-stop correction — 2026-10-08

Under the existing transaction lock, apply/revoke now durably create a
root-owned `0600` non-secret `promotion-pending` marker beside the live policy
before service operations. A negated unit path condition blocks boot/manual
startup while pending. Failure or process interruption retains the marker;
revoke retains it alongside deny-all. Successful apply fsyncs the policy file
and renamed directory entry, validates/removes/fsyncs the marker at the commit
boundary, then unmask/conditionally starts. Unmask/start errors restore/sync
inhibition before independent bounded cleanup; restoration failures are joined
with the original error, never silently claimed as durable fail-stop. Unsafe
marker symlinks/hardlinks are rejected without changing unrelated files.

The runbook requires explicit successful retry instead of manual marker
removal. After a successful retry, prior masked intent can keep the unit
inactive; an explicit operator start is allowed only after successful apply.
Normal successful-policy reboot recovery remains automatic, not re-provisioned.

| Evidence | Result |
|---|---|
| Focused RED | `go -C pkgs/nixos-scripts test ./internal/sshrelay -run '^TestPolicyDurableInhibition$' -count=1` — exit 1; all four invalid-token/unmask/start/revoke cases reproduced missing durable inhibition before stop. |
| Focused GREEN/race | `go -C pkgs/nixos-scripts test ./internal/sshrelay ./cmd/relay-policy -count=1` and same with `-race` — exit 0; failure markers survive synthetic volatile-state deletion, successful commit clears before unmask, revoke retains marker, unsafe markers preserve victims, restoration errors are joined and compensating stop runs. |
| Static/format | Focused Go vet and `nix fmt -- linux/system/services/network/ssh-relay.nix` — exit 0. |
| Public unit assertions | Nix eval — exit 0; enabled persistent-policy host, root tmpfiles parent, boot intent, and exact negated marker condition confirmed. |
| Final build/evaluation | Linux `nixos-scripts` package build, rog toplevel derivation eval, and `nix flake check --no-build path:.` — exit 0 after the final marker tests; unchanged ciphertext SHA256 confirmed. |
| Runtime boundary | Synthetic temporary files/fake systemctl only; no actual service/boot/activation, `/var`/`/run` state, deployment, DNS, remote operation or existing credential access. Native reboot inhibition is not claimed as tested. |
| Rollback boundary | Marker lifecycle helpers/commit/cleanup calls and directory sync in policy.go, marker regressions, unit condition, and correction docs/evidence; preserve initial ciphertext and unrelated work. |

Delivery slicing remains honest: the aggregate current source delta exceeds
400 lines after these correctness fixes. Initial encrypted input/host wiring
is a separate under-budget unit. Deliver the ROG correctness slice first
(Go default/marker/tests and Linux unit guard, with correction docs/evidence),
then the encrypted input/host opt-in slice (ciphertext, host declarations,
Darwin key, provisioning runbook/task evidence). The disabled-host baseline
supports the correctness slice independently; later opt-in uses its new path
and guard. Each slice remains under 400 lines; no new broad size exception.
No commit or push has been performed.

## Integrated source delivery approval — 2026-10-08

The user explicitly approved one coherent relay-only source-delivery commit for
the measured 4,044 changed lines across 29 files, plus this minimal approval
record. Shared source dependencies prevent honest whole-file historical slices.
This exception does not authorize unrelated work, credentials, activation, DNS,
deployment, or runtime readiness claims. Both hosts remain disabled.

## Phase 1 — Feasibility and RED Gates

### Completed

- [x] 1.1 User approved Rust wstunnel11.0.0 replacement; actual Linux protocol tests passed in reopened exploration and the pinned official Linux release asset builds without Rust compilation. Native Darwin package execution remains pending; Chisel is rejected, not conditionally accepted. Removed tautological fixture supplies no evidence.
- [ ] 1.2 Production-boundary RED cases. Lifecycle subset is covered below; host/runtime cases remain deferred to Unit 3.
- [ ] 1.3 Stop/change/start revocation, native Mac/retry/sleep and exact WSS443 gates remain pending.
- [x] 2.1 Minimal launchd-backed lifecycle/status implementation and tests.
- [x] 2.2 Native wstunnel binary registration and non-secret argv/header-file helper are implemented and unit/race tested. Native outage/sleep and live launchd runtime validation remain pending.
- [x] 3.1–3.3 Source integration migrated from obsolete Chisel to wstunnel; primary-user manual launchagent, off serialization, strict SSH, corrected sops YAML, conditional nginx, and documentation are preserved. Provisioning/native validation remain pending.

### Transport decision

**Current decision: user explicitly approved erebe Rust wstunnel11.0.0 with STOP-before-policy-change revocation. Exploration/#3688 remains authoritative and read-only.**

Reopened evidence is `/home/glats/.local/opencode-v2/tmp/opencode/relay-gate-20261007/{results,ws-followup-results,ws-missing-header-results}.json`. Official Linux binary SHA256 `6a1d6ab8f4537823d0a8157416b264fa1313253574143e3900eba93e17c6de49`: verified-WSS positive payload and native headers-file succeeded; declared UDP/SOCKS/HTTP-proxy/normal-forward/other bind/port and missing/empty/wrong Authorization were denied. `restrictions: []` denied old tokens after restart/hot removal; blank/{} startup failed. Established streams survived hot revoke; server stop disconnected them. Malformed hot reload retained old policy. These are disposable Linux transport results, not production SSH22, exact443, native Mac or transactional secret-update proof.

The dedicated server MUST STOP, confirm active-stream termination and inhibit restart before any policy/secret change; replace/validate current owned runtime policy, then START. Failure stays stopped, never stale-policy fallback; last removal uses `restrictions: []`. Automatic secret reload before stop is forbidden. Client uses native `--http-headers-file`; no AUTH environment or credential argv/store/log. Rotate/restart client if necessary without changing intent. No deployment/provisioning authorized.

Retain ONLY `!ReverseTunnel` protocol `[Tcp]`, port `['22220']`, CIDR `[127.0.0.1/32]`, anchored Authorization; forbid Any/Tunnel/permissive defaults. Server uses `--restrict-config <runtime-policy> ws://127.0.0.1:4012`; nginx retains WSS443 `relay.glats.org` topology and passes Authorization without logging. Client explicitly verifies TLS/system roots; nginx's persistent ACME TLS key replaces the now-obsolete Chisel SSH key/fingerprint. Final Mac SSH key/host-key authentication remains mandatory; trusted fixed Mac destination is127.0.0.1:22, not malicious-endpoint attestation.

Source/help verification in this correction confirms `-R tcp://127.0.0.1:22220:127.0.0.1:22`, `--tls-verify-certificate`, `--http-headers-file`, `--reverse-tunnel-connection-retry-max-backoff 60s`, `--connection-retry-max-backoff 20s`, `--log-lvl off`. v11 source has indefinite reverse loop,1s exponential delays capped by reverse flag and30s reverse-reply timeout; pool flag is not total process retry limit. These choices require outage/sleep/quiet-log native tests, not a second supervisor. KeepAlive=false means fatal exit remains degraded. Headers source rereads per connection; malformed file/rotation behavior remains a gate.

### Historical Chisel evidence — superseded for selection

- Locked local Nix evaluation reports Chisel `1.11.6` for both rog and macm5; it is rejected. NixHub reports patched package versions `1.11.7` and `1.11.8`, but this flake does not provide that patched package.
- The upstream v1.12.0 source build at commit `fe4f4fe7e6a849b4aa6d1b8ee47037e16033f42a` validates reverse authfile ACLs at config time and on every outbound channel (`server/server_handler.go:124-175`, `share/tunnel/tunnel_out_ssh.go:35-59`). The README documents anchored `R:127\\.0\\.0\\.1:<port>` patterns, reverse remotes, and live authfile reload semantics; removed credentials fail new authentication while established tunnels are not promised immediate interruption.
- The disposable harness invoked the actual v1.12.0 binary with synthetic credentials, loopback-only random ports, a generated self-signed CA/certificate, and a real local TCP target. It proved the exact allowed reverse listener reached the fixed target, a different reverse listener was denied, normal forwarding was denied, and a reloaded credential was rejected for a new client. The client log showed verified TLS and `Connecting to wss://127.0.0.1:<port>`.
- Linux build succeeded and `GOOS=darwin GOARCH=arm64 go build` produced a Mach-O arm64 binary. Native Darwin execution, exact TCP443 binding, DNS, and `relay.glats.org` deployment remain unverified; unprivileged local binding to 127.0.0.1:443 was unavailable.
- The earlier Chisel positive controls were insufficient: reopened actual-binary UDP/SOCKS and empty-authfile results invalidate that selection. Rust wstunnel now replaces it; older Chisel receipts do not prove replacement.

### Lifecycle implementation decision

Preserve existing launchctl-backed `relayctl`, generation checks,0700 state,0600 files, atomic replacement and off lock held through bootout. on persists intent and launches one juan-owned manual job; off cancels it. Replace Chisel-only argv/credential plumbing with native wstunnel, no Go daemon/parallel retries. Existing controller GREEN evidence remains valid; new transport retry/credential/TLS acceptance is not implied.

Source register: Chisel README https://github.com/jpillora/chisel/blob/v1.12.0/README.md; Chisel ACL advisory https://github.com/jpillora/chisel/security/advisories/GHSA-24fp-5v3p-rvpw; Chisel ACL/auth advisory https://github.com/jpillora/chisel/security/advisories/GHSA-397r-r4gr-x5pg; frp README https://github.com/fatedier/frp/blob/v0.71.0/README.md; wstunnel restrictions https://github.com/erebe/wstunnel/blob/v11.0.0/restrictions.yaml. These sources document transport and security behavior; none is a live proof for this deployment.

### User-approved trusted-client decision

The user explicitly accepted the TRUSTED macm5 client security model ("ok"). rog authenticates publication with an independently revocable per-host credential, enforces only the designated loopback listener, and denies other publications/listeners and normal forwarding. The trusted fixed managed Mac configuration forwards only `127.0.0.1:22`; rog operator independently verifies the final Mac host key and key authentication.

The relay cannot independently attest that a malicious authenticated Mac connects to its stated local endpoint. This approved trust boundary removes that attestation gate only; authentication, loopback isolation, relay/channel capability denial, runtime secret handling and independent SSH verification remain mandatory. No custom fork or general proxy is approved.

### Current transport replacement evidence

| Evidence | Result |
|---|---|
| Focused Go tests | `go -C pkgs/nixos-scripts test ./internal/sshrelay` — exit 0; fixed wstunnel argv, destination, header-file validation, ownership/mode/symlink rejection, and lifecycle behavior passed. |
| Source audit corrections | Sanitized relay-client now passes only `HOME`/`TMPDIR` to the absolute child; proxy, `WSTUNNEL_*`, certificate-override, AUTH, debug, and TLS-keylog variables are excluded. Header validation resolves the file and parent, rejects resolved Nix-store paths and writable/untrusted immediate parents, and preserves `/var` → `/private/var` resolution. Linux server preflight applies the same resolved-path/store/parent checks. |
| Race/full Go checks | `go -C pkgs/nixos-scripts test -race ./internal/sshrelay`, `go -C pkgs/nixos-scripts test ./...`, and `go -C pkgs/nixos-scripts vet ./...` — exit 0. |
| Nix package build | `nix-build --impure -E 'let f = builtins.getFlake (toString /home/glats/.nixos); pkgs = import f.inputs.nixpkgs { system = "x86_64-linux"; }; in pkgs.callPackage /home/glats/.nixos/pkgs/wstunnel-relay { }' --no-out-link` — exit 0; official precompiled Linux asset fetched by fixed SRI hash, no Rust compilation, and post-install `--version`/`--help` checks passed. Darwin asset hash was verified by `nix store prefetch-file`; native execution remains pending. |
| Official release assets | v11.0.0 `wstunnel_11.0.0_linux_amd64.tar.gz` SHA256 `9708a99717b5a951453c2ff7c14c25d3418d02ca7fcb96fdb382a8f2083bab5e`; `wstunnel_11.0.0_darwin_arm64.tar.gz` SHA256 `150e439c8b94859154903d71313b4c0b313ac9ccf99437af42573134e5051dc4`; official release asset names/checksums matched. |
| Source/host evaluation | `nix flake check --no-build` and rog system drvPath evaluation — exit 0. Darwin full-system evaluation is unavailable on this x86_64-linux runner because of an aarch64-darwin dependency. |
| Runtime harness | Existing authoritative disposable Linux wstunnel evidence in `/home/glats/.local/opencode-v2/tmp/opencode/relay-gate-20261007/` proves native headers-file acceptance and forbidden-mode denial. Native Darwin, exact production TCP443/DNS/TLS, real credentials, SSH22, revocation transaction, outage/sleep, activation, and deployment remain pending. |
| Rollback boundary | Revert only the wstunnel package/overlay binding, relay client helper, relay modules, conditional vhost, relay docs, and relay-specific host/SSH/sops additions; preserve unrelated dirty work and the completed lifecycle implementation. |

### Bounded native Mac transport verification — 2026-10-08 UTC

User-authorized temporary native checks used only existing normal `ssh`/`scp` authentication to `macm5`, with `BatchMode=yes`, `StrictHostKeyChecking=yes`, `ConnectTimeout=5`, bounded subprocess deadlines, and no authentication workaround. Public platform output was Darwin arm64, macOS 27.0.1 (26A434), HOME `/Users/juan`. No credential files, authentication databases, manual keys, decrypted secrets, shell profiles, production endpoints, or environment dumps were accessed.

- The existing official v11.0.0 Darwin archive in the approved local temporary asset directory was SHA256-checked before transfer, and again remotely: `150e439c8b94859154903d71313b4c0b313ac9ccf99437af42573134e5051dc4`, matching the pinned package asset. No download or installer was run.
- Native `file` reported `Mach-O 64-bit executable arm64`; `otool -L` reported only Apple system dependencies: Security, CoreFoundation, CoreServices, SystemConfiguration, `/usr/lib/libiconv.2.dylib`, and `/usr/lib/libSystem.B.dylib`. Execution succeeded without additional dependency installation. `--version` returned `wstunnel-cli 11.0.0`; top-level and client `--help` exited successfully and exposed TLS verification, headers-file, both retry-backoff flags, and log level.
- A juan-owned mode-0700 `mktemp` directory and a synthetic mode-0600 Authorization header file were used. Each binary invocation received only HOME/TMPDIR via `env -i`. The fixed client flags and reverse target `tcp://127.0.0.1:22220:127.0.0.1:22` ran against the disposable unavailable endpoint `wss://127.0.0.1:49199` (unavailability checked first). With `--log-lvl off`, the process remained alive after 8 seconds and emitted zero log bytes. Only the endpoint was substituted; no production connection was attempted.
- An info-level diagnostic run remained alive after 6 seconds but exposed no connection/retry lines. A separate debug-level diagnostic run remained alive after 8 seconds and showed five actual loopback TCP connection attempts, each refused with Darwin `os error 61`; successive observed intervals were approximately 0.4, 0.8, 1.6, and 3.2 seconds. This is bounded native retry evidence, not long-outage/recovery, configured-cap exhaustion, or sleep/wake proof.
- Each owned client PID was terminated explicitly with SIGTERM and reaped (exit 143). Remote cleanup traps removed all test files, and an independent normal SSH check confirmed both temporary directories absent. No launchd job, persistent installation, service activation, DNS change, production build/deployment, or commit was performed.

Native official-asset compatibility and short unavailable-endpoint retry/quiet-log checks now pass. This does not validate the installed Nix Darwin derivation, `relay-client` helper, launchd lifecycle, successful TLS trust/handshake, authenticated forwarding, final SSH22, exact production TCP443, revocation transaction, long outage/recovery, or sleep/wake. TLS verification was enabled and accepted by the native CLI; connection refusal happens before TLS, so this is not certificate-validation proof. The relay is not declared ready. Earlier pending-native statements above describe prior evidence, now supplemented only by this bounded check.

### Historical Work Unit Evidence

| Evidence | Result |
|---|---|
| Focused test command and exact result | `python3 /home/glats/.local/opencode-v2/tmp/opencode/ssh-relay-gate/harness.py` — exit 0; actual Chisel v1.12.0 server/client passed allowed reverse forwarding, unauthorized listener denial, normal-forward denial, credential revocation for new clients, TLS verification, and secret-redacted logs. |
| Packageability command and exact result | `nix eval --raw .#nixosConfigurations.rog.pkgs.chisel.version` and macm5 equivalent — both `1.11.6` and rejected; `GOTOOLCHAIN=auto go -C .../chisel build` — exit 0; `GOOS=darwin GOARCH=arm64 ... go build` — exit 0, Mach-O arm64. |
| Lifecycle focused tests and exact result | `go -C pkgs/nixos-scripts test ./internal/sshrelay -count=1` — exit 0; `go -C pkgs/nixos-scripts test -race ./internal/sshrelay -count=1` — exit 0. Covered duplicate on, serialized off/bootout versus newer on, idempotent off, stuck launch/status deadlines, unknown relay/SSH evidence, launchctl exit-3 handling, fixed destination, absolute argv, and no credential-like argv. |
| Correctness RED/GREEN result | RED command `go -C pkgs/nixos-scripts test ./internal/sshrelay -run 'TestSeparateProcessesCannotRestartSupersededOn\|TestOffBootsOutWhenState\|TestCanceledMutationsDoNotTouchIntentOrLaunch' -count=1` — exit 1 at compile time because `ErrSuperseded` was not yet implemented. GREEN rerun of the same command — exit 0 after generation checks, cleanup fallback, and context gates. |
| Full Go suite and exact result | `go -C pkgs/nixos-scripts test ./...` — exit 0; all repository packages passed. |
| Static check and exact result | `go -C pkgs/nixos-scripts vet ./internal/sshrelay ./cmd/relayctl` — exit 0. Lifecycle tests are standard-mode GREEN evidence; no false RED-first claim is made because strict TDD is disabled. |
| Host integration source checks | `nix build --impure path:/home/glats/.nixos#packages.x86_64-linux.nixos-scripts --no-link` — exit 0; `nix eval --impure path:/home/glats/.nixos#nixosConfigurations.rog.config.system.build.toplevel.drvPath` — exit 0; `nix eval --impure path:/home/glats/.nixos#darwinConfigurations.macm5.pkgs.chisel-relay.drvPath` — exit 0; `nix flake check --no-build path:/home/glats/.nixos` — exit 0. The full Darwin system evaluation is unavailable on this x86_64-linux runner because an aarch64-darwin dependency is not buildable here. |
| Pinned Chisel derivation | `nix-build --impure -E 'let f = builtins.getFlake (toString /home/glats/.nixos); pkgs = import f.inputs.nixpkgs { system = "x86_64-linux"; }; in pkgs.callPackage /home/glats/.nixos/pkgs/chisel-relay { }' --no-out-link` — exit 0; actual v1.12.0 commit `fe4f4fe7e6a849b4aa6d1b8ee47037e16033f42a`, source hash and vendor hash are fixed, and upstream tests passed. Native Darwin execution remains pending. |
| Runtime boundary | N/A for this prior source/integration unit: no activation, deployment, DNS, credential provisioning, or remote operation was authorized. |
| Rollback boundary | Remove the new relay module/package/helper/docs, their host imports/config blocks, the isolated `relay.glats.org` vhost, the rog-only alias, and the narrowly scoped future sops rule; existing LAN/link/tun configuration is otherwise untouched. |
| Local review-fix checks | `yq . .sops.yaml` — exit 0; direct `lan-mesh.nix` evaluation produced `macm5-relay` with `HostKeyAlias=macm5`, strict host-key checking, publickey-only authentication, disabled password/KbdInteractive, and `BatchMode=true`; disabled rog evaluation confirmed no `relay.glats.org` vhost or ssh-relay service; nix-darwin option evidence confirms `launchd.user.agents` renders the primary user's `~/Library/LaunchAgents`. |
| Nix verification | `nix fmt --` touched Nix paths — exit 0; `nix build --impure path:/home/glats/.nixos#packages.x86_64-linux.nixos-scripts --no-link` — exit 0, including `relay-client`; `nix flake check --no-build path:/home/glats/.nixos` — exit 0. The `path:` form was used so untracked source remained visible without staging unrelated work. |
| Runtime harness command/scenario and exact result | Authorized disposable loopback harness only; no DNS, service, credential provisioning/decryption, installer, remote operation, or production mutation. Exact TCP443 and native Darwin execution remain pending. |
| Rollback boundary | Delete only the approved temporary harness/build directory; no repository production code was added. Preserve unrelated dirty work. |

### Limits and next gate

Next apply resumes1.1 packaging,2.2 transport argv/header handling and3.1 policy/integration migration. Preserve completed2.1/local fixes and approved Unit2-only size exception/feature-branch-chain. Recount Unit1/3 changes; no broad exception. Native Darwin package/execution, exact443/nginx/header/TLS trust, safe revocation transaction, final SSH and outage/sleep/off/isolation remain gates. All current production code stays unchanged in this correction; no apply launched. Stop before activation/DNS/secret provisioning/remote operations.

### Delivery boundary

The Unit 2 lifecycle exception remains scoped to 829 Go lines (745 lifecycle source/tests). Unit 3 currently measures 342 authored additions plus 3 deletions across source/docs and existing integration files, remaining below the 400-line budget without a broad exception. No commit or PR was created here.

### ROG policy transaction source slice — stopped at review budget

This source-only slice implemented the minimal explicit `relay-policy` apply
and revoke boundary for Linux rog. It does not create secrets, decrypt sops
data, activate a host, deploy remotely, or change the macOS promotion path.

- `internal/sshrelay/policy.go` masks the fixed `ssh-relay.service` with
  `systemctl mask --runtime --now`, verifies an inactive/failed/unknown unit
  with `MainPID=0`, serializes through a root-only `0700` runtime state lock,
  validates a staged root-owned `0600` URL-safe token, generates only the fixed
  TCP `!ReverseTunnel`/`22220`/`127.0.0.1/32` policy, atomically installs a
  service-owned `0600` file, and starts only when the pre-transaction unit was
  enabled. Any validation, installation, unmask, or start failure remains
  stopped/masked; start failure applies a compensating mask. Revoke installs
  `restrictions: []` after the same stop check and intentionally leaves the
  service masked.
- `cmd/relay-policy/main.go` is a thin Linux-only `apply|revoke` operator
  command. No policy key or token is accepted through argv, environment, or
  logs. The command is registered in `pkgs/nixos-scripts/default.nix`; no
  automatic watcher or activation hook was added.
- `policy_test.go` covers stop-before-promotion and conditional restart,
  invalid staged token fail-stop, start failure fail-stop, deny-all revoke,
  ownership/mode of the promoted file, and command ordering using synthetic
  temporary files and an injected systemctl launcher.

The authored slice is **522 lines** (`313` implementation, `173` tests, `33`
thin command, and `3` registration lines), exceeding the 400-line budget. The existing
size exception applies only to the lifecycle Unit 2 work and no exception was
approved for this slice. Apply therefore stops here rather than compressing or
deleting tests. The Nix service wiring, explicit sops staging declaration,
independent verification, and macOS promotion remain pending.

#### Work Unit Evidence

| Evidence | Result |
|---|---|
| Focused test command | `go -C pkgs/nixos-scripts test ./internal/sshrelay -count=1` — exit 0; 19 tests passed. |
| Race test command | `go -C pkgs/nixos-scripts test ./internal/sshrelay -race -count=1` — exit 0; 19 tests passed. |
| Full package test command | `go -C pkgs/nixos-scripts test ./... -count=1` — exit 0; 411 tests passed across 44 packages. |
| Static check | `go -C pkgs/nixos-scripts vet ./...` — exit 0. |
| Cross-build check | `GOOS=darwin GOARCH=arm64 go build ./cmd/relay-policy` — exit 0; runtime remains Linux-rejected by design. |
| Runtime harness | N/A: this slice intentionally used an injected launcher and temporary files only; no real systemctl, activation, deployment, credentials, or endpoint was authorized. |
| Rollback boundary | Remove `pkgs/nixos-scripts/internal/sshrelay/policy.go`, `policy_test.go`, `pkgs/nixos-scripts/cmd/relay-policy/main.go`, and the one `default.nix` subpackage entry. |

### Independent ROG policy security correction — 2026-10-08

The approved review overlay at
`/home/glats/.local/opencode-v2/tmp/opencode/relay-policy-security-review/overlay.json`
was read before editing. Its reproduced defects were converted to regression
tests before the production fixes: failed/partial unmask could leave the unit
unmasked; canceled start cleanup inherited the canceled context; writable or
symlinked ancestors were accepted; an existing runtime-directory symlink was
chmodded before the first system command; the stop proof accepted unknown or
empty PID state; and the transaction lock accepted symlink/hardlink paths.

The correction now uses an independent bounded cleanup context and joins the
original error with cleanup verification failure. It positively requires
`LoadState=masked`, `ActiveState=inactive`, and `MainPID=0` after masking. It
validates every existing path component without following symlinks, refuses
unsafe existing directories instead of chmodding them, opens staged/lock files
with no-follow flags, checks regular ownership/mode/link count, and compares
the opened descriptor inode with the named path before and after staged-token
read. The live policy staging file is also created no-follow with exclusive
creation and atomically renamed. The Linux unit explicitly declares
`KillMode=control-group` and `TimeoutStopSec=5s`.

Regression tests were written first and failed 5/6 on the unfixed source; the
review overlay separately reproduced the prior permissive unknown/empty-PID
state handling, and the corrected test now requires the explicit three-field
masked/inactive/zero proof.
After correction all 26 `internal/sshrelay` tests pass, including hardlink and
symlink path cases. The fixed policy remains generated from the URL-safe staged
token; arbitrary YAML parsing and secret watchers were not added.

#### Correction evidence

| Evidence | Result |
|---|---|
| Focused RED | `go -C pkgs/nixos-scripts test ./internal/sshrelay -run 'TestPolicyApplyRemasksWhenUnmaskFails\\|TestPolicyApplyUsesIndependentCleanupContextAfterCancellation\\|TestPolicyRejectsWritableAndSymlinkAncestors\\|TestPolicyDoesNotMutateExistingSymlinkedRuntimeDirectory\\|TestPolicyRequiresMaskedInactiveUnitAndExplicitZeroPID\\|TestPolicyRejectsSymlinkedTransactionLock' -count=1` — exit 1, 1 passed and 5 reproduced failures before fixes. |
| Focused GREEN | `go -C pkgs/nixos-scripts test ./internal/sshrelay -count=1` — exit 0; 26 passed. |
| Race/static | `go -C pkgs/nixos-scripts test ./internal/sshrelay -race -count=1` and `go -C pkgs/nixos-scripts vet ./internal/sshrelay ./cmd/relay-policy` — exit 0; 26 race tests passed, vet clean. |
| Full Go | `go -C pkgs/nixos-scripts test ./... -count=1` and `go -C pkgs/nixos-scripts vet ./...` — exit 0; 418 tests passed across 44 packages. |
| Cross-platform compile | `GOOS=darwin GOARCH=arm64 go test -c .../internal/sshrelay` and `GOOS=darwin GOARCH=arm64 go build ./cmd/relay-policy` — exit 0; the command still rejects non-Linux at runtime. |
| Native policy harness | Disposable actual wstunnel v11.0.0 loopback server/client with the generated fixed policy and synthetic header/token forwarded a positive payload through only TCP/22220/127.0.0.1; processes were temporary and terminated. TLS-verified production connectivity was not claimed. |
| Runtime harness boundary | No real systemctl, activation, sops materialization, service deployment, DNS, remote operation, or credential read/decryption was performed. |
| Final authored count | 779 lines for the existing policy work unit after this correction, including 380 implementation, 361 tests, 33 command, 3 registration, and 2 Nix service settings. The user-approved 522-line exception covers the original unit; these are correctness fixes within that same unit and add no new broad exception. |

### macOS credential promotion source unit — 2026-10-08

The prior independent review passed all five ROG policy corrections. This
separate macOS source unit adds no ROG policy changes and no credential
material. `relayctl credentials apply|revoke` uses the existing controller's
single state lock, so `On` and `Off` cannot interleave with promotion.

- Apply records a generation, boots out the GUI job, waits for launchd to
  report `ErrNotLoaded`, then validates the user-owned staged token and
  atomically installs `Authorization: Bearer ...` as the juan-owned `0600`
  header. It restarts only when the pre-transaction intent was enabled.
- An initially disabled relay remains disabled. Any validation, promotion,
  state-write, bootout, or restart failure retries bootout under an independent
  bounded context and disables intent; cleanup errors are joined rather than
  claimed as successful fail-stop.
- Revoke never restarts: it stops first, validates/removes the live header, and
  leaves intent disabled. The staged token is never read during revoke.
- The Darwin module now derives matching authorization/header paths under
  `/Users/juan/Library/Application Support/nixos/ssh-relay`, declares the
  future system-sops authorization secret with `owner = primaryUser` and
  `mode = "0600"` only when the relay is enabled, and keeps the launch agent
  disabled by default. No encrypted file exists and no sops activation ran.

#### Work Unit Evidence

| Evidence | Result |
|---|---|
| Focused tests | `go -C pkgs/nixos-scripts test ./internal/sshrelay -count=1` — exit 0; 31 passed, covering initially-off preservation, enabled-only restart, invalid-stage fail-stop, revoke clearing, and concurrent `On` serialization. |
| Race/static checks | `go -C pkgs/nixos-scripts test ./internal/sshrelay -race -count=1` and `go -C pkgs/nixos-scripts vet ./internal/sshrelay ./cmd/relayctl` — exit 0. |
| Full Go checks | `go -C pkgs/nixos-scripts test ./... -count=1` and `go -C pkgs/nixos-scripts vet ./...` — exit 0; 423 passed across 44 packages. |
| Darwin source proof | `GOOS=darwin GOARCH=arm64 go test -c .../internal/sshrelay` and `GOOS=darwin GOARCH=arm64 go build .../cmd/relayctl` — exit 0. |
| Nix source evaluation | `nix eval --impure --json path:/home/glats/.nixos#darwinConfigurations.macm5.config.services.ssh-relay` — exit 0; derived headers/authorization paths match and enable remains false. |
| Native/runtime harness | N/A: no native launchd job, sops materialization, secret, activation, deployment, DNS, or remote operation was authorized. |
| Rollback boundary | Revert `relay.go` credential methods/config fields, `client.go` token/header helpers, `credentials_test.go`, `cmd/relayctl/main.go`, and the Darwin ssh-relay module's credential options/conditional sops declaration. |
| Final authored count | 337 lines for this macOS unit: 113 controller, 52 client helper, 135 tests, 15 CLI, and 22 Darwin-module lines. Below 400; no new exception. |

### macOS independent security corrections — stopped at work-unit boundary

The approved synthetic overlay at
`/home/glats/.local/opencode-v2/tmp/opencode/mac-review-overlay_test.go`
reproduced three defects in the source unit:

1. Assigning the custom sops `path` allowed the stage to be a final symlink,
   while `ReadAuthorizationToken` correctly rejects symlink leaves but therefore
   could not consume the materialized secret.
2. Revoke used the weaker header validator and could follow a symlinked parent
   toward an unrelated user-owned file before removal.
3. `ValidateHeaderFile` accepted a hardlink and writable ancestor chain.

The Darwin module now leaves the sops secret at its default secure path with
`owner = primaryUser` and `mode = "0600"`; the separately configured
`authorizationFile` remains a regular user-owned staging path for a future
explicit materializer. No custom sops `path` assignment remains. Header
validation/revocation now require the trusted full chain, a private user parent,
no-follow open, matching descriptor identity, and a unique regular `0600` file.
The trusted-chain helper permits only root-owned sticky temporary roots (such as
`/tmp`) while still rejecting writable non-sticky ancestors, symlink ancestors,
and hardlinks. Revoke fails closed without deleting the victim.

#### Correction evidence

| Evidence | Result |
|---|---|
| Focused regressions | `go -C pkgs/nixos-scripts test ./internal/sshrelay -count=1` — exit 0; 36 passed, including custom-stage symlink rejection, symlinked-ancestor revoke preservation, writable-ancestor rejection, and hardlink rejection. |
| Race/static checks | `go -C pkgs/nixos-scripts test ./internal/sshrelay -race -count=1` and `go -C pkgs/nixos-scripts vet ./...` — exit 0; 36 race tests passed, vet clean. |
| Full Go suite | `go -C pkgs/nixos-scripts test ./... -count=1` — exit 0; 428 passed across 44 packages. |
| Darwin source proof | `GOOS=darwin GOARCH=arm64 go build .../cmd/relayctl` — exit 0. |
| Darwin config proof | `nix eval --impure --json path:/home/glats/.nixos#darwinConfigurations.macm5.config.services.ssh-relay` — exit 0; fixed paths are derived and enable remains false. |
| Runtime boundary | No secret, sops activation, native launchd operation, service activation, DNS, deployment, remote operation, commit, or push was performed. |
| Final work-unit count | 431 authored additions / 473 changed lines relative to the pre-Mac source baseline: the original 337-line Mac unit plus 94 correction additions. This exceeds 400 by 31; no new exception was granted, so apply stops here and stages the materializer as separate pending task 5.2. |

### macOS regular staging materializer — task 5.2

Implemented the separate, bounded materializer unit. `relayctl credentials
stage <source-path>` reads no secret from argv; the path is only a source
locator. It accepts a regular default sops output or a final symlink only when
the symlink is root-owned, all resolved ancestors are trusted/non-writable,
and the opened target is the expected owner `0600` regular file with one link
and matching descriptor identity. User-owned symlinks, unsafe ancestors,
hardlinks, invalid tokens, Nix-store targets, and changed files are rejected.

The validated token is atomically copied to the fixed juan-owned regular
staging path. Invalid input leaves the prior staging file unchanged. The
operation holds the existing controller lock, performs no launchctl call, and
does not touch live headers; `credentials apply` remains the only
stop-before-live promotion operation. The Darwin sops declaration now keeps
the default `/run/secrets/ssh-relay/authorization` path instead of assigning a
custom symlink path. No encrypted file exists and no activation ran.

#### Materializer evidence

| Evidence | Result |
|---|---|
| Focused tests | `go -C pkgs/nixos-scripts test ./internal/sshrelay -count=1` — exit 0; 38 passed, including valid/idempotent staging, invalid-source preservation, user-symlink rejection, no live-header change, and no launchctl calls. |
| Race/static checks | `go -C pkgs/nixos-scripts test ./internal/sshrelay -race -count=1` and `go -C pkgs/nixos-scripts vet ./...` — exit 0; 38 race tests passed, vet clean. |
| Full Go suite | `go -C pkgs/nixos-scripts test ./... -count=1` — exit 0; 430 tests passed across 44 packages. |
| Darwin source proof | `GOOS=darwin GOARCH=arm64 go build .../cmd/relayctl` — exit 0. |
| Nix/source docs | sops-nix documentation confirms default secret paths are `/run/secrets/$name` and custom paths become root-managed symlinks; Darwin config eval remains disabled and no sops file is present. |
| Runtime boundary | No real source secret, decryption, sops activation, launchd/service operation, deployment, DNS, remote operation, commit, or push was performed. |
| Rollback boundary | Revert the `StageCredentials` method, trusted sops-source reader, atomic stage writer, `relayctl credentials stage` branch, staging tests, and the staging workflow documentation. |
| Final materializer count | 160 authored additions, below 400; no exception. |

### Source-chain correction and ROG staging — task 5.3

Corrected the task 5.2 source guard after review found that checking only the
resolved chain could accept a root-owned sops symlink below an originally
writable ancestor. The shared validator now checks every original and
resolved/traversed ancestor for an allowed root or expected-user owner and no
group/other write bits, permits normal root-owned OS symlinks only after their
resolved chain is trusted, bounds source traversal depth, and retains no-follow
descriptor, regular-file, `0600`, single-link, inode-identity, and post-read
checks. Existing regular-source and live-header guards remain unchanged.

Added the separate root-only `relay-policy stage <source-path>` operation. It
uses the corrected source primitive and atomically writes the fixed regular
root-owned `0600` stage at `/run/ssh-relay-staging/authorization` under a
separate trusted lock. It does not call systemd, mask the relay, replace the
live policy, or expose the source contents in argv. `relay-policy apply` now
reads only this fixed stage; apply/revoke lifecycle behavior is unchanged.

#### Task 5.3 evidence

| Evidence | Result |
|---|---|
| Focused tests | `go -C pkgs/nixos-scripts test ./internal/sshrelay -count=1` — exit 0; 40 tests passed, including source-chain rejection/preservation, cycle rejection, and ROG staging without service calls. |
| Full/static checks | `go -C pkgs/nixos-scripts test ./... -count=1`, `go -C pkgs/nixos-scripts vet ./...`, and Darwin arm64 builds of `relay-policy` and `relayctl` — exit 0; 432 tests passed across 44 packages, vet clean, both builds succeeded. |
| Namespace boundary | `unshare -Ur ... go test ./internal/sshrelay -run 'Test(StageCredentialsSyntheticRootSopsLink\|PolicyStageSyntheticRootSopsLink)'` — exit 0; trusted root-owned symlink and writable-original-parent rejection both passed. The host disallowed `--mount-proc`; the test was rerun without that optional flag. |
| Runtime harness | N/A: staging is a source-only filesystem transaction; no real sops source, systemd service, live policy, deployment, or remote endpoint was authorized. |
| Rollback boundary | Revert the shared source-chain validator correction, ROG staging helper/CLI branch, policy stage regressions, documentation, and task/evidence entries; leave prior Mac apply/revoke and unrelated dirty work intact. |
| Budget | Task 5.3 is a separate bounded source-only unit; no size exception was used. |

### Bounded blocker re-verification — 2026-10-08 UTC

The fresh apply session first inspected the aborted workspace and confirmed that
the two requested source fixes were already present. The source-chain resolver
walks original and resolved components before each dereference, with bounded
symlink hops; the `relay-policy stage` CLI branch runs before the configured
service-account lookup and transaction constructor. No duplicate production
fix was added.

Added focused regressions for a writable intermediate source ancestor and a
trusted two-hop source chain. The CLI now has a small testable `run` boundary;
this also exposed and corrected a stale exported `PolicyTransaction` type
reference, while preserving exit status 2 for usage errors. The stage path is
still a fixed root-only materializer and the test seam does not invoke
systemctl or perform service-account lookup.

#### Re-verification evidence

| Evidence | Result |
|---|---|
| Focused RED/GREEN | The new namespace regression initially failed because the test directory's requested `0777` mode was reduced by umask; after explicitly setting `0777`, the unsafe intermediate ancestor was rejected and the trusted multi-hop chain passed. This was a test-fixture correction, not a fabricated compile-only RED. |
| Focused tests | `go -C pkgs/nixos-scripts test ./cmd/relay-policy ./internal/sshrelay -count=1` — exit 0. |
| Namespace source-chain tests | `unshare -Ur sh -c 'go test ./internal/sshrelay -run "TestStageCredentials(SyntheticRootSopsLink\|ChecksEveryIntermediateSourceAncestor\|AcceptsTrustedMultiHopSource)\|TestPolicyStageSyntheticRootSopsLink" -count=1'` — exit 0. |
| Race/static | `go -C pkgs/nixos-scripts test -race ./internal/sshrelay ./cmd/relay-policy -count=1` and `go -C pkgs/nixos-scripts vet ./...` — exit 0. |
| Full Go suite | `go -C pkgs/nixos-scripts test ./... -count=1` — exit 0 across all packages. |
| Darwin cross-build | Separate `GOOS=darwin GOARCH=arm64 go build` commands for `cmd/relay-policy` and `cmd/relayctl` — exit 0; both produced Mach-O arm64 binaries. |
| Runtime boundary | No systemctl, service-account provisioning, sops source, secret, activation, deployment, DNS, remote operation, or live mutation was performed. |
| Rollback boundary | Revert only the source-chain regression tests, CLI `run` test boundary/type correction, and this evidence entry; preserve all unrelated dirty files and prior relay work. |

### Provisioning feasibility plan — read-only, 2026-10-08 UTC

This is planning evidence only. No encrypted relay file, plaintext credential,
deployment, activation, remote mutation, or secret decryption was performed.
The latest bounded native macOS evidence above is retained unchanged: official
Darwin arm64 execution, quiet unavailable-endpoint behavior, and native retry
checks passed, while successful production TLS/SSH forwarding remains pending.

#### Existing ownership and recipient boundary

- `.sops.yaml` already has the narrow future rule for
  `secrets/shared/ssh-relay.yaml`, with public recipients `admin_glats`,
  `host_rog`, and `host_macm5`; no relay ciphertext file currently exists.
- rog uses the system sops module from `linux/system/base/sops.nix`, with the
  generated machine key at `/var/lib/sops-nix/key.txt` and the host SSH key
  path configured there. The canonical host declaration file is
  `hosts/rog/secrets.nix`; existing service secrets use explicit owner/group
  and mode fields.
- macm5 imports `inputs.sops-nix.darwinModules.sops` in the system
  configuration. `darwin/system/sing-box-link.nix` already configures the
  system SSH host-key input and root-owned templates. The user Home Manager
  module separately uses `~/.config/sops/age/keys.txt`; no private identity was
  read, and the relay plan does not assume that the Home Manager key can
  decrypt a host-recipient-only file.
- Therefore the smallest recipient-safe design uses the macOS system sops
  path for the relay material, renders a root-owned staging template, and
  performs an explicit root-owned promotion to the juan-owned `headersFile`.
  It avoids weakening the header to world-readable mode or inventing a new
  user recipient before key ownership is independently confirmed.

#### Smallest initial provisioning workflow

1. An authorized operator creates one URL-safe opaque Authorization token on a
   trusted machine and encrypts only its ciphertext into
   `secrets/shared/ssh-relay.yaml` for the existing three public recipients.
   The repository agent must not create, read, decrypt, or display that token.
2. Add conditional system sops declarations only when the relay is enabled:
   rog reads the token into a service-owned staging template; macm5 reads the
   same token into a root-owned staging header template. Do not use
   `restartUnits` or `reloadUnits`; those mechanisms can update a watched file
   without the required stop boundary.
3. Render native, non-secret templates into staging paths under the existing
   sops runtime directories (`/run/secrets/rendered/<name>` for system sops).
   Use `/run/ssh-relay/restrictions.yaml` as the rog live policy and
   `/Users/juan/Library/Application Support/nixos/ssh-relay/headers` as the
   macOS live header, with private parents created by the transaction. The rog
   policy template contains exactly one
   anchored Authorization matcher and one `!ReverseTunnel` allow rule for
   `Tcp`, port `22220`, CIDR `127.0.0.1/32`; the macOS template contains only
   `Authorization: Bearer <token>`. The token must never be placed in argv,
   environment, Nix store, plist, or logs.
4. Promote staging to live files only while both relay jobs are disabled. The
   rog live policy is a regular `0600` file owned by `ssh-relay`; the macOS
   live header is a regular `0600` file owned by `juan` in a private,
   non-store parent. Validate regular-file type, ownership, mode, resolved
   path, parent safety, and native policy syntax before any first start.
5. Keep `services.ssh-relay.enable = false` during this initial materialization.
   Only a later, separately authorized deployment may enable the server/client
   jobs after native TLS, authenticated forwarding, final SSH22 host-key, and
   isolation gates pass.

#### Required rotation and revocation transaction

The current source has safe stop/off primitives but no single operation that
holds the lifecycle lock across staging promotion and conditional restart.
That is the remaining source blocker; an activation-only promise is not
enough. The smallest follow-up is one narrow transaction boundary, not a new
supervisor or general secret framework:

1. sops updates only the staging templates. The live files consumed by
   wstunnel and `relay-client` do not change.
2. Acquire the existing relay lifecycle lock, record whether intent was
   enabled, stop/bootout the dedicated job, and confirm the process and active
   streams are gone. Inhibit restart while the lock remains held.
3. Validate the staged policy/header and atomically install them into the live
   paths with the existing ownership/mode/resolved-parent guards. A malformed
   policy or failed install leaves the relay stopped and does not fall back to
   the old active policy.
4. Release the restart inhibition only after successful promotion. Restart
   exactly when the prior intent was enabled; otherwise remain disabled.
   Preserve the existing `KeepAlive = false`/`RunAtLoad = false` behavior.
5. For final revocation, stop both sides first, promote `restrictions: []` on
   rog (deny-all) and remove/disable the macOS header, then leave both jobs
   stopped. Do not rely on wstunnel hot reload as immediate revocation.

On Linux, the existing system activation ordering can stage through sops-nix
before a guarded service transaction. On macOS, Home Manager sops runs through
its user launchd agent and the system sops module writes system templates during
post-activation; the promotion must therefore be explicitly ordered after
materialization and still use the relay lifecycle lock. A plain `sops` template
or `restartUnits` declaration is insufficient proof of this transaction.

#### Feasibility blockers and next gate

- No source edits are made in this planning slice. The narrow transaction
  primitive and its RED tests must be designed before any encrypted relay file
  is created.
- The exact macOS root-to-juan promotion path and activation ordering require a
  native/evaluated nix-darwin proof; no private age identity or secret content
  may be inspected to obtain it.
- The existing lifecycle-only size exception remains the only exception. This
  planning append adds no new feature work-unit or broad review-budget
  exception.

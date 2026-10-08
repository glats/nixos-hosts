```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:7922cf789b9ab6ae6b262629c1d63a4a3c1e6a7369169d9b94cf40abb4c13aef
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 1/7
scenarios: 2/10
test_command: "go -C pkgs/nixos-scripts test ./... -count=1"
test_exit_code: 0
test_output_hash: sha256:607d9c825d5d6e6c227bd3fa0817ea8515289bdae5e9e7afbfe9fd1d71123c8d
build_command: "nix build .#packages.x86_64-linux.nixos-scripts --no-link"
build_exit_code: 0
build_output_hash: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

## Bounded closure evidence — 2026-10-08

This is a bounded delivery PASS with warnings, not a successfully executed native
final phase or formal archive approval. Source gates and earlier basic relay SSH
PASS; user confirmed off/on and explicitly accepted delivery to master and closure.
The client is intentionally OFF now: relay unavailability is expected, not a
source failure. Full native verification/archive remain BLOCKED by pending tasks.

Source: detached `c00e35e3b32371fe815bdb3be189682a60ca129a` in
`/home/glats/.local/opencode-v2/tmp/opencode/relay-policy-darwin-fix`.
The envelope evidence revision hashes that commit ID plus LF. All proposal,
spec, design, tasks and apply-progress artifacts were read. The authoritative
delta has seven requirements and ten scenarios.

`git fetch origin` succeeded: origin feature equals HEAD; origin/master is
`2c2279d53dbc04697a7b0f0f6176724904cb3849` and is an ancestor of HEAD. Source
delivery can fast-forward without history rewriting at this snapshot; recheck
future refs before delivery. The unrelated dirty primary checkout was preserved.

## Native status and execution scope

Native `sdd-status`/`sdd-continue --json`: 10/15 tasks complete, five pending,
`dependencies.verify=blocked`, `dependencies.archive=blocked`, next `apply`;
actionContext is repo-local with this temporary workspace as allowed edit root.
Instructions require every task complete before final verification, and a
resolving report plus every task complete before archive. Report existence alone
does not satisfy either gate. Checkboxes remain apply-owned and unchanged here.

The bounded runtime-bearing evidence reconciliation was acquired with work unit
`bounded-apply-evidence-reconciliation`, goal `source-c00-readonly-runtime-snapshot`,
one attempt, 250 changed lines. The untracked tool file `.gentle-ai-instance` was
explicitly excluded. This is not a bypass of blocked native final verification.
That historical attempt changed only this report and apply-progress. This later
artifact correction and authorized Git delivery do not launch/reset another
runtime-bearing attempt. No product edits, archive, spec sync, DNS, deployment or
service mutation are authorized here.

## Independent checks

| Check | Result |
|---|---|
| `go -C pkgs/nixos-scripts test ./... -count=1` | PASS, exit 0; platform/opt-in skips are not native proof. |
| `nix flake check --no-build` | PASS, exit 0; Darwin omitted. Output SHA-256 `c039898129f841f1d5d618b18387b6758f7ec82337f1b8f1cfeddb2c40ee37dc`. |
| `nix build .#packages.x86_64-linux.nixos-scripts --no-link` | PASS, exit 0, cached realization/empty output; not Darwin deployment. |
| `SSHRELAY_NATIVE_UNIT_CHECK=1 go -C pkgs/nixos-scripts test ./internal/sshrelay -run '^TestPolicyNativeUnitConditionReadOnly$' -v -count=1` | PASS, exit 0; actual installed condition and effective manager configuration checked read-only. |
| `systemctl show ssh-relay.service --property=ActiveState,SubState,NeedDaemonReload,ConditionResult,Result` | Both observations active/running, reload no, condition yes, result success. |
| `ss -ltn 'sport = :22220'` | Both observations local listener exactly `127.0.0.1:22220`; peer `0.0.0.0:*` is not a global bind. |
| `ssh -G macm5-relay`, filtered nonsecret options | juan, loopback:22220, hostkeyalias macm5, strict checking, identities-only, publickey-only, BatchMode; password/keyboard-interactive disabled. |
| Strict pinned SSH, two historical bounded observations | Exit 255 twice: timeout during banner exchange; cause unclassified at observation, no remote command output. |

SSH command:
`ssh -n -T -oConnectTimeout=8 -oConnectionAttempts=1 -oBatchMode=yes -oStrictHostKeyChecking=yes -oHostKeyAlias=macm5 -oControlMaster=no -oControlPath=none macm5-relay 'hostname; uname -m'`.
Second observation: `2026-10-08T17:51:14Z`; log hash
`d33c5d7c974a50329605a8905fe9ab98e52d96fbcbf838f8b10bad0c299e2481`.
Logs: `/home/glats/.local/opencode-v2/tmp/opencode/relay-close-{go,flake,build,runtime}.log`.

Earlier parent evidence obtained `CLFTCLGV2FHWW0W.local`, `arm64`, exit 0.
User confirmed ROG policy apply/service active, Mac stage/apply/on and off
failure/on restoration. These remain genuine earlier evidence, not current
reproduction by this verifier. Banner-timeout cause is unclassified; Mac sleep,
local SSH state and transport health were not diagnosed. An open listener alone
cannot be relabeled current SSH success. No further retries/recovery were made.

Correction recorded at `2026-10-08T17:58:15Z` from explicit parent evidence, not a
new runtime probe by this delivery agent. Parent's later strict BatchMode LAN SSH
(six-second bound) returned `CLFTCLGV2FHWW0W.local`, `arm64` and
`intent=disabled registered=no pidunknown relayunknownsshunknown`; its parallel
relay SSH returned `127.0.0.1:22220 Connection refused`. Exact acquisition time
of this later parent snapshot was not supplied. It establishes intentional OFF
and expected current relay unavailability, not the cause of the earlier banner
timeouts. No fresh on-state connection is claimed or required for this accepted
basic delivery; no hidden on, restart, sleep, reboot or revocation test is run.

## Scenario evidence matrix

Completion counts conservatively count bounded status coverage only; other full
scenarios remain partial, not inferred from earlier happy-path SSH.

| Scenario | Automated/source | Native/current | Result |
|---|---|---|---|
| Authorized connection | Fixed WSS/TLS/reverse destination/environment tests pass. | Earlier parent SSH exit 0; user off/on confirmed; later client intentionally OFF. | PASS basic delivery; broader native scenario remains partial. |
| Identity failure | TLS verify arguments and strict alias. | Native bad TLS/identity rejection not reproduced. | PENDING native negative. |
| Denied publication | Earlier real Linux binary rejection harness; policy stop/inhibit/deny-all failure tests pass. | No production active-stream revocation/capability negatives. | PARTIAL. |
| Local listener and secret containment | Runtime-only interfaces, owner/mode/parent/hardlink/environment/argv tests pass. | Exact loopback bind observed; no secret content read. | PARTIAL broader containment. |
| Operator access | Strict alias inspected. | Earlier authorized PASS; later OFF expected refusal; unauthorized key/host mismatch untested. | PARTIAL broader native gate. |
| Nightly outage and recovery | Persistent policy/durable inhibition and capped native retry source proof. | No actual nightly reboot/outage recovery. | PENDING native longevity. |
| Stop racing recovery | Bootout serialization/generation/idempotence/cancellation tests pass. | User off/on confirmed, not a measured outage/recovery race. | PARTIAL. |
| Incomplete evidence | `TestStatusIsBoundedAndDoesNotClaimRelayOrSSH` passes, unknown remote evidence retained. | Listener/current SSH failure distinction preserved here. | PASS bounded contract. |
| Stalled probe | Bounded launcher/status tests and finite context deadlines pass. | Native DNS/TLS/SSH stall matrix not exercised; controller does not claim those remote results. | PASS automated contract, native warning. |
| Noninterference | Separate alias/vhost/backend; no TUN/routes/supervisor addition. | No before/after LAN/linkctl/vhost/login/app baseline. | PARTIAL. |

## Findings and warnings

`policy.go` loaded-unit fallback requires inactive/MainPID=0, exact effective
negated durable condition and `NeedDaemonReload=no`; tests reject stale manager
state, reset/ineffective conditions and unsafe markers. Opt-in installed-unit
test independently passed. Persistent `/var/lib/ssh-relay/restrictions.yaml`,
root-owned parent and durable `promotion-pending` guard have source regressions,
not actual reboot proof. c00 preflight uses escaped `%%a`/`%%u`; installed service
is active after user's actual start. Mac source includes the narrow approved
platform root-daemon-path trust exception and private stage-parent regressions;
native Mac metadata tests skip on Linux.

No decrypted credentials/policy plaintext, authorization key files or private
identities were read. No rotation, revocation, stop, reboot, sleep/wake or
production promotion was performed. Nightly reboot, sleep/wake, active-stream
revocation, full native rejection and isolation remain unproven.

## Formal archive blockers and delivery ownership

1. Pending native tasks: 1.2, 1.3, 2.3, 3.4, 4.1. Apply should reconcile stale
   4.1 against user transaction/service evidence; 6.1 is already checked and
   shipped. 1.3 includes broader native gates, not just shipped staging source.
   Do not check 3.4 from off/on alone or remove/narrow its remaining revocation,
   outage, sleep and isolation tests. 1.2/2.3 retain native obligations too.
2. No current on-state connection is claimed: Mac is intentionally OFF. This is
   a delivery warning, not an additional source/runtime blocker. Historical
   banner-timeout cause remains unclassified. Basic delivery acceptance is
   explicit; it does not waive the outstanding formal native gates.

Master-delivery authority is distinct from native archive acceptance. User accepts
basic observed SSH and off/on for delivery closure. This report grants neither
formal archive readiness nor fresh current on-state E2E evidence. Remaining
nightly reboot, outage, sleep/wake, active-stream revocation, native negative and
isolation validation remains explicitly pending; no tasks are checked or moved.
After legitimate task reconciliation/completion, rerun native status, independent
final verification and report validation before archive handoff. Delivery owner
may include these two artifacts in a closure commit; exclude `.gentle-ai-instance`.

Historical report validation succeeded (`valid=true`, verdict fail, 7 requirements/10
scenarios). Post-report native status still blocks verify/archive and reports
`failed verification evidence is incomplete; rerun SDD verification`.
The one bounded attempt settled failed with 155 charged lines, no active attempt,
and `decision_required=true`, `next_action=reset`; objective revision is
`sha256:fdb1c4d150478a4f60b77b91f2d239c8567e15406b5faf509c819a803e12952d`.
The failure evidence revision is the runtime-log hash above. No automatic reset
was performed: another runtime-bearing attempt requires an explicit maintainer
scope decision and native reset, not merely a passing source test. This correction
does not change that historical tool record or claim fresh native validation.
The corrected envelope is scoped to basic delivery, not seven completed formal
requirements or ten completed scenarios. Formal archive remains pending.

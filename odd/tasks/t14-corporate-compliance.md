# t14 corporate compliance
Objective: implement corporate-agent source configuration for t14 without disrupting working access. Branch: `feat/complaince`; historical baseline: `ae9cebe650b8fd12f55f243fc9d685fef235f577`; implementation baseline: `804133f7db14680e367d3d90abe284e7575a684e`; integrated master: `3e5a637402cebf902c2baff51c66ae85da33b492`.
Delivery: `exception-ok`; the user now requests publication of the TLS correction on `feat/complaince` (L25), retaining normal master merges and no Feature Flow, rebase, force-push or PR. Source checks are recorded in L23–L24; post-merge checks precede push. No assistant build, deployment, activation, enrollment or other remote runtime mutation is authorized. Earlier publication and default-TMPDIR evidence remain in L18–L22; built-wrapper and live proof of the new correction remain pending.

## Specs

### S1 — Target and intended outcome

Original request: "neceisto que mi mac t14 tenga el software complaince (netsckope creo que y quizas otros mas que tines que verifica) asi poder usar teams outlook etc".

The user selected "ThinkPad (t14)" when asked to distinguish it from macm5. The target is the NixOS ThinkPad, not the Mac. Determine the relevant corporate software rather than assuming every installed Mac product is mandatory.

Acceptance: each inventoried product has a documented Linux disposition, evidence, and remaining prerequisites. Installation alone is not evidence of enterprise compliance.

### S2 — Inventory before integration

"yo creo que habria que inspeccoinar primero lo que tien macm5 en su sittma, con ese congloremado ver el equoivalente en linux. ademas nix peude perfectamente comodar el software para que sea buutnu rhel. total es solo un flavor".

Use the observed Mac inventory as the comparison set: Netskope Client, Netskope Endpoint DLP, CrowdStrike Falcon, Company Portal/Intune, ForeScout SecureConnector, InvGate Insight, and FortiClient. Distinguish technical adaptation from vendor support, feature parity, enrollment, and tenant acceptance. Absence from a support matrix is not proof of technical impossibility.

Acceptance: record authentic Linux packages or installers, dependencies, integration uncertainty, and company-bound provisioning needs without recording credentials. Do not falsify device or OS identity.

### S3 — Preserve working access and investigate proactively

"en t14 ya funciona todo eso." and "podemos se proactivos?".

Teams, Outlook, GCP, and internal access already work according to the user. This is a preventive integration, not a reproduced access failure. Do not equate working access with proof of compliance, or claim a specific agent is required without evidence.

Acceptance: before any activation, define a repeatable access baseline for the same services; after an authorized activation or enrollment, repeat it and check the intended agent's actual operation. Do not manufacture an initial failure or a RED result.

### S4 — Actual target inspection

"puedes usar ssh t14.lan oara inspeccionar".

SSH access is authorized for inspection. Remote changes, sudo, installations, enrollment, service restarts, or activation are not implied. Preserve SSH access in any future authorized rollout.

Acceptance: report declared configuration separately from observed runtime state and identify limitations of each probe. Do not collect secrets, tokens, detailed profiles, raw process arguments, or browser data.

### S5 — Exclude firewall work

"el firewall es tedioso. lo scaria por mientras.".

Keep the existing firewall state unchanged. Disk encryption and Secure Boot are separate from this corporate-agent initiative; their observed state does not authorize changing them.

Acceptance: no firewall, partition, encryption, boot-chain, or generated hardware-configuration changes in this initiative.

### S6 — One ODD initiative for the whole scope

"yo haria odd para todos los puntos de una.".

Track Intune preparation, deployment-impact review, enrollment verification, Netskope, Falcon, the disposition of the remaining inventoried products, and integrated access verification together. One initiative does not mean one simultaneous installation.

Acceptance: maintain stable task IDs, evidence and external gates in this document and its Engram mirror. Separate configuration preparation from activation and enrollment. Do not create empty agent modules while vendor artifacts are missing.

### S7 — One command for the integrated compliance mode

"dale. otra cosa que queiro es activar o desactivar esto (todo lo que tiene que conver con complaince) con un comando, basta con systemctl ?"

Provide a single command interface to enable or disable the integrated corporate-compliance components. The scope is the agents and configuration actually implemented in this initiative, not an assertion of tenant compliance. The user selected "Persistente (Recomendado)": the chosen mode must survive reboot. Command names and mechanism are not fixed yet.

Acceptance: report the actual selected mode and limitations honestly; do not confuse stopping services with removing enrollment. Preserve access to SSH and do not bypass agent anti-tamper controls. Use the repository's Go operational-tool convention if a new custom command is needed. Switching modes on the real device still requires explicit activation authorization; no runtime mutation is authorized merely by this requirement.

### S8 — Intune Portal TLS packaging correction (source-only)

"si. y bueno para edge funcionara igual o no?" and "funciona. ahora aparece para poner el correo. es encesario que siga por alli o con eso estamos?" (L23).

The Intune Portal must receive a GIO TLS provider compatible with the pinned glib-networking through its package, so the portal starts without manually exporting `GIO_EXTRA_MODULES`. The change is limited to wrapping the portal binary inside its own package output; the package version, ELF handling, arguments, certificate verification, and the existing ON/OFF gating remain unchanged.

Acceptance: a static evaluation shows the portal derivation carries the wrapper declaration and the pinned glib-networking module path, while the OFF child remains without the portal. This is source preparation only: it does not claim that Edge sync, tenant compliance, or end-to-end enrollment is fixed, and no broker, Edge, root-service, or CA-trust change is part of it. Runtime proof and deployment remain pending.

## Tasks

- [x] T1 — S1–S4: inventory Mac, inspect live t14, and verify pinned Intune feasibility; route: inline state checks plus delegated read-only mapping (mapping budget); evidence: L3–L5; commit: none, read-only.
- [ ] T2 — S1, S3–S6: Intune source prepared and evaluated; deployment-impact review remains pending; route: delegated implementation by explicit user request, independent security verifier completed; evidence: L7–L8 and L22; implementation commit: `48ff7a45e2e45c17c96207dbf6635d60648bed13`.
- [ ] T3 — S1–S3, S5–S6: obtain the authentic Netskope Linux artifact through approved provisioning, verify needed features and prepare the smallest viable integration; route: inline implementation when authorized, independent verifier for privileged network integration; gate: installer and provisioning method; commit: pending, not authorized.
- [ ] T4 — S1–S3, S5–S6: obtain the authentic Falcon Linux artifact, verify kernel/backend compatibility and prepare the smallest viable integration; route: inline implementation when authorized, independent verifier for security impact; gate: sensor artifact and provisioning method; commit: pending, not authorized.
- [ ] T5 — S1–S2, S5–S6: finish Linux feature/packaging disposition for Netskope Endpoint DLP, ForeScout, InvGate and FortiClient; route: inline bounded research or one read-only explorer if mapping exceeds budget; no implementation unless a concrete need is established; commit: none for research.
- [ ] T6 — S3–S6: validate the complete authorized candidate, document rollback and conduct separately authorized activation/enrollment with repeated access checks; route: inline coordination plus independent verification before deployment; gates: candidate, functional proof and explicit remote-change authorization; commit: pending, not authorized.
- [ ] T7 — S3–S7: selectable ON/OFF Nix configurations and the Go `compliance-mode on|off|status` CLI are source-prepared, independently verified and integration-tested; system build, activation, reboot and live runtime/boot proof remain pending; route: delegated implementation per user preference; evidence: L15–L22; implementation commit: `48ff7a45e2e45c17c96207dbf6635d60648bed13`.
- [ ] T8 — S8: Intune Portal wraps its own binary with the pinned glib-networking GIO module path (ON only). Source preparation, independent static verification and post-merge checks passed; these are evaluation-only. Publication authorized in L25; fix commit `e4a6294415e90bc809ec5528bd3e7748dd7d01e7`. Built wrapper, deployment, runtime checks, Edge sync and enrollment remain unverified; evidence: L23–L26.

## Log

### L1 — Original request

"neceisto que mi mac t14 tenga el software complaince (netsckope creo que y quizas otros mas que tines que verifica) asi poder usar teams outlook etc"

### L2 — User scope and corrections, 2026-10-22

- Target selection: "ThinkPad (t14)".
- "yo creo que habria que inspeccoinar primero lo que tien macm5 en su sittma, con ese congloremado ver el equoivalente en linux. ademas nix peude perfectamente comodar el software para que sea buutnu rhel. total es solo un flavor"
- "no her preobaod nada estamos reicen convensaod que recomeindas? vamos con odd?"
- "en t14 ya funciona todo eso."
- "podemos se proactivos?"
- "puedes usar ssh t14.lan oara inspeccionar"
- "el firewall es tedioso. lo scaria por mientras."
- "dale. como anvamoz?"
- "yo haria odd para todos los puntos de una."

### L3 — Observed baseline, 2026-10-22

The local Mac has Netskope Client 138.1.12.2776, Netskope Endpoint DLP 138.0.0.3572, Falcon 8.10, Company Portal 5.2608.0, ForeScout SecureConnector 33.0.33001, FortiClient 7.4.3.4323 and an InvGate Insight agent. Selected service-state probes found running Netskope, Intune, ForeScout and InvGate components. The Falcon sensor and Netskope proxy extensions are enabled. MDM status is enrolled, user approved. DLP activity and the FortiClient VPN connection remain unverified.

Read-only SSH inspection of t14 found NixOS `26.05.20260822.a9e6d84`, kernel `7.1.9-zen1`, Edge and teams-for-linux. No matching corporate system services/unit files or loaded user services were found, and selected known agent commands were absent from the SSH PATH. This bounded search is not proof that no other component exists.

`firewall.service` was not found/inactive; packet-filter rules were not inspected. Root XFS and swap are direct NVMe partitions with no visible LUKS layer. The Secure Boot EFI flag is disabled; TPM devices exist. These observations do not establish enterprise policy requirements or authorize changes.

### L4 — Verified Intune feasibility and deployment gate, 2026-10-22

Main nixpkgs is locked to `4382ed2b7a6839d4280a9b386db49cbc5907414d`. The exact module exposes `services.intune.enable`; it adds the portal and identity broker, a broker system user/group, systemd packages, tmpfiles and D-Bus integration. It does not perform enrollment. The package-source inspection reported portal `1.2603.31-noble` and broker `3.0.1`, for `x86_64-linux`, with no OS-identity rewriting in the examined Nix expressions. Vendor-binary behavior remains unverified.

Source: <https://github.com/NixOS/nixpkgs/blob/4382ed2b7a6839d4280a9b386db49cbc5907414d/nixos/modules/services/security/intune.nix>.

Potential edit surfaces, not yet written: `linux/system/services/security/intune.nix` and a direct import in `hosts/t14/default.nix`. Existing keyring and Edge configuration may be reusable, but interactive sign-in has not been tested. The live system revision differs from the current lock; deployment must account for unrelated changes instead of blindly switching.

### L5 — Private-agent and feature gates, 2026-10-22

Netskope Linux distribution uses a tenant-provided `STAgent.run`; Falcon uses a tenant-provided `.deb` or `.rpm`. Provisioning must use the actual approved company method; no keys or tokens belong in chat, Git, this file or memory. No vendor installers have been obtained. Installer adaptation must run authentic agents, not falsify device posture. Kernel/backend support for the live Zen kernel remains unverified.

Sources: <https://docs.netskope.com/en/netskope-client-for-linux/> and <https://www.crowdstrike.com/tech-hub/endpoint-security/installing-falcon-sensor-for-linux/>.

Netskope Endpoint DLP Linux parity is not established by the examined supported-platform list. ForeScout documents a Linux SecureConnector service. InvGate's exact Linux installation requirements and FortiClient's required VPN/EMS feature set remain open. Installed Mac products are not automatically mandatory for t14.

ForeScout source: <https://docs.forescout.com/modules-plugins/endpoint/linux-plugin/linux-plugin/manage_endpoints_using_secureconnector_10350_d137e1_d138e1.htm>.

### L6 — Implementation and checking boundaries, 2026-10-22

Current authorized deliverable was the unified plan and its memory mirror. No source implementation, activation, enrollment, staging, commit, push or PR was performed at that point. Keep historical OpenSpec artifacts untouched. Baseline Git state was clean on `feat/complaince` at `ae9cebe650b8fd12f55f243fc9d685fef235f577`.

Implementation route at that point was inline per task because no writer-delegation reason was present. Independent verification remains required for security/network changes; source-normalizing commands precede functional verification. Before implementation, load matching Nix and package-specific skills and verify proposed options against the pinned source. Native review remains user-owned and, if applicable, separate from deployment authorization.

Passive planning had no meaningful runnable RED test; structural readback was its proportional check. For future configuration, format touched Nix files with `nix fmt -- <path>` and evaluate `nix eval .#nixosConfigurations.t14.config.system.build.toplevel.drvPath` in a context containing the intended new files without silently staging them. A derivation-path evaluation is not a build, enrollment test or proof of compliance. Any builds require a cost/side-effect forecast and an authorized execution environment. Package behavior changes use deterministic RED → GREEN tests when an appropriate runner exists; otherwise record the limitation and use applicable integration proof.

Forecast: Intune should be a small host-only change; total authored lines for private-agent integration cannot be estimated reliably before inspecting the artifacts. No delivery slice or PR is selected. Reforecast before implementation work-unit commits; if the feature is expected to exceed roughly 400 authored changed lines, resolve the delivery strategy before any authorized commit. Commits and publication remain pending explicit authorization.

Next at that point: review the unified scope, then prepare the Intune configuration when source changes are authorized while resolving the two private-installer gates in parallel. ForeScout, InvGate, FortiClient and DLP remain disposition tasks, not assumed installation requirements. Mirror topic: `odd/t14-corporate-compliance/tasks`.

### L7 — Authorization update and delegated T2 route, 2026-10-22

Latest user request was verbatim: "no nada de atlarsisna. vamos por la impletnacion en t14 entonces?¡" and then "delega!". This explicitly authorizes local source preparation for T2 as a delegated write unit: add a minimal t14-only Intune module import and evaluate it locally. This authorization is source-preparation only and does not authorize activation, installation on t14, enrollment, remote mutation, staging, commit, push, PR creation or Atlassian uploads.

T2 route status is now delegated implementation for local declarative preparation under bounded edit surfaces (`hosts/t14/default.nix`, `linux/system/services/security/intune.nix`, this task file), with verification through local formatter and host-scoped `nix eval` checks that include untracked files via `path:$PWD`. Firewall state and other unrelated host behavior remain unchanged by scope.

### L8 — Intune implementation and independent verification, 2026-10-22

Added only `services.intune.enable = true;` in `linux/system/services/security/intune.nix`, imported directly by t14. The writer observed the actual option baseline `false`, then `true` after implementation. `nix fmt -- linux/system/services/security/intune.nix hosts/t14/default.nix` succeeded with zero formatting changes. Explicit `path:$PWD` evaluation included untracked sources without staging. Intune enablement, the broker system user and the complete t14 toplevel derivation path evaluated successfully; the firewall value remained `false`. The parent reran the enablement evaluation and observed `true`. `git diff --check` passed.

An independent verifier created baseline/candidate copies in an approved system temporary directory, not in the workspace. It reproduced `false` → `true`, the broker user creation, unchanged firewall, kernel version `7.1.9` and systemd-boot enablement, and a valid candidate toplevel derivation. Only t14 imports the new module. No blockers were found. A nonfatal upstream `system` → `stdenv.hostPlatform.system` rename warning was observed; no source workaround was added. Different scratch-source paths produced different derivation hashes, so these are evaluation results, not a frozen deployable binary or build receipt.

Risk: item 2 (security services and identity broker). Native assessment reported high/unassessable because untracked files need an explicit inventory declaration; this did not lower risk. RDD status is off by explicit global preference, so no native review was started or preference changed. Independent verification still ran.

No system build, installation on t14, activation, enrollment, interactive sign-in or runtime access test was performed. T2 stays open for deployment-impact review and its separately authorized delivery boundary; T3/T4 still need private Linux artifacts. Rollback of this source preparation is removal of the t14 import and new module only; there is no activated generation or enrollment to undo. No firewall, kernel, boot, encryption, hardware configuration, credentials or unrelated source was changed. No staging, commit, push, PR or Atlassian upload occurred.

### L9 — Unified mode-control request, 2026-10-22

User request verbatim: "dale. otra cosa que queiro es activar o desactivar esto (todo lo que tiene que conver con complaince) con un comando, basta con systemctl ?". The user accepted proceeding toward impact review/build and requested a unified control interface. No system build has started; resolve reboot persistence before selecting and building a mode-control implementation. No activation, enrollment or commit authorization is inferred.

NixOS MCP, explicit channel 26.05, confirms the `specialisation` option supports additional system configurations and documents runtime activation. This is a candidate mechanism, not an implemented command. Ordinary service control alone does not establish complete agent shutdown, reverted networking, or removal of enrollment. Only authentic agent-supported lifecycle actions may be used; anti-tamper controls must not be bypassed. S7/T7 are added while existing task IDs and verified evidence are preserved.

### L10 — Persistence decision, mechanism research and execution block, 2026-10-22

The user selected "Persistente (Recomendado)" in response to whether the mode should survive reboot. S7 and T7 now record that decision. Native runtime specialisation switching alone does not update the system profile or guarantee the next boot selection.

A read-only explorer and one scoped independent assumption check examined the pinned NixOS activation/bootloader implementation. The candidate mechanism uses native system-profile selection followed by activation; restoring ON must match the exact parent whose specialisation resolves to the OFF closure, never choose an unrelated historical ON generation. EFI default overrides can defeat persistence; `bootctl set-default` is not the proposed mechanism because it can pin stale generations across rebuilds. Actual child activation and reboot persistence remain unproven. No profile, bootloader, EFI variable or service was changed.

Two delegated implementation attempts stopped before edits: a fresh writer could not load its required instructions, and the previously functional writer session then reported no direct filesystem/command tools. No RED/GREEN or T7 implementation is claimed. Parent state capture confirmed only the prior Intune import/module and this task document remain changed. Do not continue source implementation inline against the user's delegation preference without a new decision.

Needs a decision: resume in a session with functional delegated repository tools, or explicitly authorize direct parent implementation. All earlier verified Intune source preparation is preserved; no system build, activation, enrollment, staging or commit occurred.

### L11 — Explicit pause and delegated resume, 2026-10-22

The user selected "Retomar con delegación" from the recovery choices. Stop implementation attempts in this session and resume in a session with functional delegated filesystem/command tools. Do not implement inline. Keep T7 pending, preserve all existing source work and resume from this document and its full memory mirror. No additional activation, enrollment, build, staging or commit authorization was granted.

### L12 — Master integration before resume, 2026-10-22

User request verbatim: "puedes traerte unos cmabios de master por favor . leugo cotnunamos". Fetched `origin/master` and fast-forwarded `feat/complaince` from the historical baseline to `804133f7db14680e367d3d90abe284e7575a684e` (21 existing commits, no new merge commit). Content hashes confirmed that all three pending compliance files were unchanged by the integration. `git diff --check` passed. New implementation and verification must use this integration baseline and current pins; prior evaluation evidence predates upstream flake changes.

### L13 — Explicit delegated retry remains blocked, 2026-10-22

User request verbatim: "ya. intenta delegando de nuevo. debe estar arreglado". Parent reconciled the actual task file and full mirror before retrying. The writer first reported a skill-loading block. A diagnostic continuation reported native tool names and a successful `nix-verify` invocation, but supplied no raw invocation output. The next continuation requested a choice about reloading skills; the user selected "Re-run nix-verify too (recommended)". That exact selection was returned once to the same actor. The final result was blocked, claiming tool execution was unavailable in that response path, with no edits or commands observed.

No T7 implementation, RED/GREEN, or repair confirmation is claimed. Stop automatic retries; preserve delegated implementation preference and earlier Intune source work. Next resume requires a worker that actually executes a harmless skill/read/status probe with observable tool results before committing to implementation. No source implementation or target mutation occurred during this retry.

### L14 — Fresh-session continuation still cannot implement, 2026-10-22

User request verbatim: "dale continbuamos entonces". The fresh worker that had reported a successful skill/read/shell probe first stopped on skill prerequisites. A separate bootstrap then reported all five required skills loaded successfully. The subsequent implementation continuation again returned blocked, reporting unavailable repository-native tools and no executed reads, commands, edits or tests. The minimal probe did not establish a working implementation path. T7 remains pending; do not infer stable execution or attempt more automatic retries. Prior source work and the no-activation boundary remain unchanged.

### L15 — Worker-model change and explicit T7 retry, 2026-10-22

User request verbatim: "listo. ya cambie el worker de codex a haiku. probemos." This authorizes one delegated T7 implementation attempt in a fresh worker session. It does not authorize system build, sudo, SSH, service changes, activation, profile/EFI/boot mutation, enrollment, staging, commit, push, PR, Atlassian use or secret access. T7 remains pending until command, test and live proof exist. Scope for this phase: `hosts/t14/default.nix`, `linux/system/services/security/intune.nix`, a new `linux/system/services/security/compliance-mode.nix`, and this task file. The new module provides `corporate.compliance.enable` (default on for t14), the `corporate-compliance/mode` marker, and a `compliance-off` specialisation; it is a preparation of selectable configurations, not the persistent command and not proof of reboot persistence.

Result: RED `nix eval --no-write-lock-file "path:$PWD#nixosConfigurations.t14.config.specialisation" --apply 's: builtins.hasAttr "compliance-off" s' --json` → `false`. After `nix fmt` (0 files changed) and edits, the same command → `true`. Parent evaluation: compliance `true`, Intune `true`, marker `on\n`, firewall `false`, kernel `7.1.9`. Child `compliance-off`: compliance `false`, Intune `false`, marker `off\n`, firewall `false`, kernel `7.1.9`, no nested specialisation. Both `system.build.toplevel.drvPath` evaluated (not built). `git diff --check` passed. Only t14 imports `compliance-mode.nix`. Pending: system build, activation, and reboot persistence proof; the persistent command (S7/T7) is not complete.

### L16 — Independent ON/OFF verification and tracking repair, 2026-10-22

The parent repeated the child Intune evaluation and observed `false`. An independent verifier used fresh external scratch copies of integration baseline `804133f7` and the candidate, reproduced ON/Intune true and OFF/Intune false with matching markers, verified no nested child specialisation, and evaluated both complete toplevel derivations without builds. Firewall, kernel `7.1.9`, systemd-boot and EFI-touch configuration remained equal to baseline. No code blockers were found. One verifier expression initially used an incorrect child `.config` suffix; the corrected `.configuration` path succeeded, so this was a probe error rather than a candidate defect.

The writer did not perform the requested MCP pre-write check. The verifier subsequently confirmed `specialisation` and `services.intune.enable` through the explicit NixOS 26.05 catalog; actual locked-input evaluation supplies target compatibility evidence. Do not claim the pre-write procedure was followed. Nonfatal upstream evaluation warnings remain advisories. Risk stays item 2 (security services and identity broker); native assessment was high/unassessable due untracked inventory, and the user's global RDD OFF preference was preserved.

Parent resolution of the current `flake.lock` root `inputs.nixpkgs` selects node `nixpkgs_2` at `a9e6d84f9c2f9012f5fe7d964a7851352300e61a`. Earlier `4382ed2b` research in this log must not be used as proof for the current target pin. The successful parent/child evaluations above use the actual root input; future implementation must resolve that edge rather than choosing a similarly named nixpkgs node.

The writer replaced the full Engram task mirror with a summary. The parent is restoring the complete file from preserved mirror history plus the actual current document, with readback and content-fingerprint reconciliation. T7 is no longer blocked on delegated tools: the Nix phase is verified, but the Go command, persistence transitions and real deployment remain unimplemented. No system build, activation, enrollment, profile/EFI mutation, staging, commit or upload occurred.

### L17 — Go command phase, mechanism correction and delegated route, 2026-10-22

User request verbatim: "adelante". This authorizes the local Go command implementation for T7 under the explicit allowed surfaces in the parent task: `pkgs/nixos-scripts/cmd/compliance-mode/`, `pkgs/nixos-scripts/internal/compliancemode/`, `pkgs/nixos-scripts/default.nix`, `pkgs/nixos-scripts/default_test.go`, `linux/system/services/security/compliance-mode.nix` (only if command metadata requires it), `docs/t14-corporate-compliance.md`, and this task file. Hosts and Intune modules are read-only for this phase. Local tests, Go builds and Nix format/eval only; no sudo, system build, activation, reboot, enrollment, real profile/EFI/default mutation, SSH, service stop, secrets, staging, commit, push, PR or Atlassian. Route: delegated writer for the Go command; parent performs independent verification; native review remains off by user preference.

Mechanism correction with evidence. The proposed OFF selection (`nix-env --set <parent>/specialisation/compliance-off` then switch) was probed in a temporary local profile: `nix-env -p <tmp>/profile --set /nix/store/<source>/nixos` produced a profile link to the store root `/nix/store/<source>` with the `nixos` subpath dropped. A specialisation subdirectory therefore cannot be selected as a profile generation with `nix-env --set`. Pinned `systemd-boot-builder.py` writes the loader default only for the generation whose bootspec init parent equals the invoked toplevel, and writes specialisation entries `nixos-generation-N-specialisation-<name>.conf`. Pinned `switch-to-configuration-ng` runs `install-bootloader` for both `switch` and `boot`. systemd's Boot Loader Interface documents `LoaderEntryDefault`, `LoaderEntryPreferred` and `LoaderEntryOneShot` under vendor GUID `4a67b082-0a4c-41cf-b6c7-440b29bb8c4f`; these can override the loader.conf default.

Chosen mechanism for this phase: the profile stays on the paired ON parent generation N. OFF writes `default nixos-generation-N-specialisation-compliance-off.conf` into loader.conf (atomic replacement of only the default line) and runs `<parent>/specialisation/compliance-off/bin/switch-to-configuration switch`; ON writes `default nixos-generation-N.conf` and runs `<parent>/bin/switch-to-configuration switch`. The selected generation is its own paired parent, so no historical ON scan or generic fallback exists. This deviates from the parent's earlier nix-env profile plan and needs parent acceptance. Persistence is limited to the boot default until a native rebuild rewrites loader.conf. No `nix-env` or bootctl command is used.

Test-first plan: stub API and behavior tests first (RED observed), then implementation (GREEN), then gofmt, `nix fmt`, the required Go commands, and host-scoped Nix evaluations. Live proof remains pending.

### L18 — Go command implementation evidence and pending boundaries, 2026-10-22

Files: `pkgs/nixos-scripts/internal/compliancemode/compliancemode.go` (logic), `compliancemode_test.go` (behavior tests through `Run` with a fake runner and temporary store, profile, loader and EFI trees), `pkgs/nixos-scripts/cmd/compliance-mode/main.go` (thin entry point), `pkgs/nixos-scripts/default.nix` (subPackage registration), `pkgs/nixos-scripts/default_test.go` (registration test), and `docs/t14-corporate-compliance.md`. The Nix compliance module, Intune module and t14 host were not edited in this phase.

RED: with an API-only stub, `go -C pkgs/nixos-scripts test ./internal/compliancemode` failed the behavior tests (exit 2, empty stdout and stderr, no state change), and `go test -run TestDefaultNixBuildsComplianceModeCommand .` failed before registration. GREEN: `go -C pkgs/nixos-scripts test ./internal/compliancemode ./cmd/compliance-mode` → `ok` for `internal/compliancemode` (33 behavior cases including subtests; permission cases ran as uid 501 and none skipped); `cmd/compliance-mode` has no test files. The registration test passed after the `default.nix` update.

Required commands: `go -C pkgs/nixos-scripts vet ./...` → exit 0. `go -C pkgs/nixos-scripts test ./...` → exit 1, failing packages `internal/aiassets` (`TestReconcileRemovesEmptyParentsOfRetiredFiles`, `TestReconcileOwnership`, `TestSecondUpgradeInterruption`, `TestReconcileProcessLock`) and `internal/sshrelay` (`TestApplyCredentialsKeepsInitiallyOffRelayOff`, `TestApplyCredentialsRestartsOnlyPriorEnabledIntent`, `TestRevokeCredentialsClearsHeaderAndIntent`, plus a panic in a parallel relay test). Baseline causality: an untouched `git archive HEAD` copy of `pkgs/nixos-scripts` in the approved temporary directory reproduced the same aiassets and sshrelay failures (macOS symlink and temp-path trust checks), so they are pre-existing and unrelated. They are not named under a Known environmental failures heading in this task, so the required command stays failing until the parent decides.

Nix: `nix fmt -- pkgs/nixos-scripts/default.nix` → 0 files changed. Explicit `path:$PWD` evaluation: parent `corporate.compliance.enable` true, `services.intune.enable` true, marker `on\n`, firewall false, kernel 7.1.9, specialisation present; child `compliance-off` false, Intune false, marker `off\n`, firewall false, kernel 7.1.9, no nested specialisation. Parent toplevel drvPath `/nix/store/gv6kj62s0m6b7535b39v3lplw1sybd80-nixos-system-t14-26.05.20260822.a9e6d84.drv` (changed from the Nix-phase path because `nixos-scripts` now includes the new subPackage); child toplevel drvPath `/nix/store/39fzvai5wizhp76wnahxb2izfrx3x5z0-nixos-system-t14-26.05.20260822.a9e6d84.drv`. Shared checks: `nix flake check --no-build --no-write-lock-file "path:$PWD"` → exit 0 (build skipped); `darwinConfigurations.macm5` toplevel drvPath evaluated; `homeConfigurations.t14` and `homeConfigurations.macm5` activationPackage drvPaths evaluated. `git diff --check` → exit 0.

Mechanism deviation (needs parent acceptance): see L17. The implementation selects OFF and ON through the native boot entry and the paired parent generation, not `nix-env --set`, because the pinned `nix-env` drops specialisation subpaths.

Limitations and pending gates: no live proof on t14; no system build, switch, reboot, or EFI/boot-entry verification; no unenrollment; the lock serializes this tool only and no test covers the lock; `status` exits 1 for unknown state by design; rebuilds reset the boot default to ON; pruning the paired parent makes ON refuse. T7 remains unchecked until parent independent verification, the required-command decision, and separately authorized live proof.

### L19 — Independent review, mechanism acceptance and regression adoption, 2026-10-22

Independent review (Engram observation 312, as reported by the parent; this worker did not re-read it): no code blockers; the corrected loader.conf and paired-parent mechanism of L17 is technically accepted as source preparation only. The parent accepted that source-level adjustment from the deterministic `nix-env` probe and the pinned `systemd-boot-builder.py` proof. This is not runtime, build, activation, enrollment, Git or deployment authorization.

Regression adoption: six probes from the independent scratch verification were ported into `internal/compliancemode/compliancemode_test.go` with exact assertions and no new production code. The RED step is an explicit exception: the production behavior already existed and the probes had already passed independently. Added tests: `TestConcurrentOffIsSerializedAndIdempotent` (two concurrent OFF requests yield one switch and one applied plus one already-off), `TestConcurrentOppositeTransitionsEndConsistent` (concurrent OFF and ON end in a consistent status), `TestRejectedCommandsLeavePersistedDataUnchanged` (tree hash excluding the lock file is unchanged by rejected commands, with no runner calls), `TestLoaderTransitionPreservesUnrelatedLinesAndLeavesNoTemp` (comments, unrelated keys and a missing trailing newline are preserved; no `.tmp` left), `TestSwitchUsesPairedClosureExecutables` (OFF runs the child switch, ON runs the parent switch), and `TestNewerProfileRefusesOlderRuntime` (exact refusal text; tree hash unchanged). The test helper `treeHash` fails the test on walk errors and excludes `compliance-mode.lock` by name.

Observed commands:
- `gofmt -l pkgs/nixos-scripts/internal/compliancemode`: no output (clean).
- `TMPDIR="$(cd "${TMPDIR:-/tmp}" && pwd -P)" go -C pkgs/nixos-scripts test -count=1 -race -v ./internal/compliancemode`: exit 0; 23 top-level tests PASS, including the six new ones; `ok ... internal/compliancemode 2.555s`; no data race reported.
- `TMPDIR="$(cd "${TMPDIR:-/tmp}" && pwd -P)" go -C pkgs/nixos-scripts test ./...`: exit 0; 37 packages `ok`; no FAIL lines.
- `go -C pkgs/nixos-scripts vet ./...`: exit 0.
- `git diff --check`: exit 0.
- Default-TMPDIR evidence kept unchanged: the earlier `go -C pkgs/nixos-scripts test ./...` without the canonical TMPDIR exited 1 with `internal/aiassets` and `internal/sshrelay` failing; the same failures reproduced on untouched HEAD (L18). The canonical-TMPDIR run above is the only normalized suite run, as authorized; the default-TMPDIR failure is not erased by it.

Documentation: `docs/t14-corporate-compliance.md` now states that `compliance-mode` must not run concurrently with `nixos-rebuild`, other bootloader writers or profile operations (the lock covers only this tool, and external races are detected but not prevented), records the rebuild-resets-ON behavior, and documents the canonical-TMPDIR test command.

Pending: system build, activation, reboot and live boot-entry proof on t14; the rebuild-persistence proof; enrollment and access-baseline checks; staging, commit and any PR. Task T7 remains unchecked.

### L20 — Targeted regression recheck and source-preparation outcome, 2026-10-22

The parent reran `TMPDIR="$(cd "${TMPDIR:-/tmp}" && pwd -P)" go -C pkgs/nixos-scripts test -count=1 ./internal/compliancemode` and observed success; `git diff --check` passed. The independent verifier then compared production files byte-for-byte against its earlier verified candidate and confirmed they were unchanged. It adopted the final test file into its external scratch copy and ran only the six new regression tests with `-race -count=1`; all six passed, with no same-scope blockers. No second broad review or unrelated source correction was performed.

Source preparation for the CLI is verified. The canonical-TMPDIR complete suite and full vet pass as recorded in L19; the earlier default-TMPDIR failures remain documented environmental evidence, not erased or silently labeled passing. The corrected paired-parent boot-entry mechanism is accepted for source preparation, not as live reboot proof. Build, activation, enrollment, runtime access and reboot/rebuild interaction checks remain pending separate authorization. No actual t14, profile, EFI, bootloader or service changes, staging, commit, push or upload occurred. Risk remains items 2 (privileged security mode), 4 (concurrency) and 5 (boot-selection environment).

### L21 — Explicit commit, master-merge and push authorization, 2026-10-23

User request verbatim: "sube esta rama pero que tenga ademas lo ultimio de master. sin feature flow". After the parent listed all ten pending compliance paths and asked about a commit, normal master merge and push without rebase, force-push or PR, the user selected "Sí, commit y push". This authorizes those Git actions only, not installation, activation, enrollment or a system build.

Fetched `origin/master`: eighteen existing commits ahead of integration baseline `804133f7`, with no unique feature commits yet. Upstream also changes `pkgs/nixos-scripts/default.nix`; preserve the local command registration by committing the reviewed implementation first, then perform a normal merge. Refresh applicable tests and evaluations on the merged candidate before publishing. Delivery strategy is `exception-ok` for this explicitly selected single-branch, single-implementation-commit publication, not a chained PR or Feature Flow. The coherent command, regression tests, docs and historical task evidence exceed the advisory line heuristic; do not remove tests or compress code to meet it.

### L22 — Publication resume and refreshed integration evidence, 2026-10-29

User request verbatim: "podemos continuar?". Publication authorization from L21 remains in scope. Implementation commit `48ff7a45e2e45c17c96207dbf6635d60648bed13` contains the ten reviewed paths (1,668 added lines). The first ordinary merge was `f6f6f92a31f60ecd9d67979c18f6f6b632f740e8`, incorporating master `556f143161834f5588c174f5082d14c8178f3602`. Its verification was interrupted; no successful push was claimed.

On resume the branch was clean. Fetched 31 newer master commits and merged without conflicts as `c0f7c3afa22f3d7c9fd17032b2725036c23f17bd`, with master `75becf3ef47fa8e5ea22c12de2bfde9efd5c5b28` as second parent. Compliance Go source/tests, docs and security modules are byte-identical to implementation commit `48ff7a45`. Both `cmd/compliance-mode` and upstream `cmd/test-shutdown` are registered once. No rebase, force-push, Feature Flow integration branch or PR was used.

A fresh independent verifier used an external scratch archive of exact merged HEAD. The full Go suite with canonical TMPDIR, `go test -count=1 -race ./internal/compliancemode`, and `go vet ./...` passed. An initial probe put TMPDIR inside the archived flake tree, causing tests that search ancestor flakes to fail; moving TMPDIR outside the tree corrected that probe error without code edits. The previously documented default-TMPDIR issue is preserved as historical evidence.

`nix flake check --no-build --no-write-lock-file` passed. Its default platform coverage skipped other systems, so a separate targeted `nix flake check --no-build --all-systems --no-write-lock-file` was run once and passed. This evaluates all declared systems but builds no derivations. t14 parent and child toplevel paths, macm5 Darwin toplevel, and t14/macm5 standalone Home Manager activation paths all evaluated. Parent/child Intune and mode remained true/false with on/off markers; firewall false, kernel `7.1.9`, systemd-boot true. Root nixpkgs remains `nixpkgs_2` at `a9e6d84f9c2f9012f5fe7d964a7851352300e61a`.

The parent spot check `TMPDIR="$(cd "${TMPDIR:-/tmp}" && pwd -P)" go -C pkgs/nixos-scripts test -count=1 ./internal/compliancemode` passed. `git diff --check` passed and the repository stayed clean throughout verification. Global RDD remains off; no review lifecycle or preference changes occurred. This documentation follow-up records implementation/merge identities and proof before the authorized normal push; the confirmed remote result is recorded in session memory after publication. No system build, activation, enrollment, SSH, profile/EFI/boot or service mutation is authorized or performed.

### L23 — Intune Portal TLS packaging correction, source-only, 2026-10-29

User requests verbatim: "si. y bueno para edge funcionara igual o no?" (authorizing a permanent source correction, without deployment, after the parent's proposal to prepare it in Nix) and, after a manual per-process trial, "funciona. ahora aparece para poner el correo. es encesario que siga por alli o con eso estamos?".

Observed context: the installed portal `1.2603.31-noble` with broker `3.0.1`; a host-side curl to the Microsoft public OIDC endpoint returned HTTP 200, which does not prove that the portal's own request worked (the portal HRD request failed with http 0); the isolated GIO default lacked a TLS provider. The existing `glib-networking` module enables GnuTLS. A user-broker-only transient experiment did not fix the portal; launching the portal with `GIO_EXTRA_MODULES` pointing at that module made the email-entry screen appear. This proves only initial portal UI progress in that trial context. It does not prove full authentication, tenant compliance, or Edge profile sync, and the transient broker unit may still run on the host and must not be touched by this work.

Source-map correction: the pinned `intune-portal` package (nixpkgs `a9e6d84f9c2f9012f5fe7d964a7851352300e61a`, `pkgs/by-name/in/intune-portal/package.nix`) is a plain `stdenv.mkDerivation`, not an FHS environment. Earlier FHS assumptions were incorrect; this clarification supersedes them without rewriting history. The package patches ELF files in `buildPhase` and sets `dontPatchELF = true`, which must be preserved.

Decision: add a host-scoped `nixpkgs.overlays` entry in `linux/system/services/security/intune.nix`, gated by `corporate.compliance.enable`, that wraps only `$out/bin/intune-portal` with `GIO_EXTRA_MODULES` pointing at the same pinned `glib-networking` output. The OFF child keeps the original package absence. The broker, the intune agent and daemon, Edge, root services, CA trust, and the package version are not changed.

Scope: source only, four allowed paths (`linux/system/services/security/intune.nix`, `tests/t14-intune-tls.nix`, `docs/t14-corporate-compliance.md`, and this task file). No build, deployment, restart, SSH, authentication, enrollment, staging, commit, push, PR, or Feature Flow is authorized or performed. The live manual trial is temporary and distinct from this source change; its cleanup is outside this task. The user's trial proves initial UI progress only, and the Edge sync remains unverified.

Evidence (source only, no build or deployment): RED, before the module change, `nix eval --impure --no-write-lock-file --json --expr 'import ./tests/t14-intune-tls.nix { flake = builtins.getFlake ("path:" + builtins.toString ./.); }'` failed with exactly `portalWrapsGioTlsProvider, wrapperNativeInputPresent`; the other five checks passed. GREEN after the change: the same command returned all seven checks `true`. `nix fmt -- linux/system/services/security/intune.nix tests/t14-intune-tls.nix` reformatted two files. Host evaluations after the change: t14 parent toplevel `/nix/store/49bwiy6yi5miffd39abv59y8pz79mzfy-nixos-system-t14-26.05.20260822.a9e6d84.drv`, child toplevel `/nix/store/kbf2qms0bw8605kmb3rilmzdrn29vvz8-nixos-system-t14-26.05.20260822.a9e6d84.drv`; mode marker `on\n` (parent) and `off\n` (child); firewall `false`; kernel `7.1.9`. `git diff --check` passed and `flake.lock` is unchanged. Only `hosts/t14/default.nix` imports the Intune module. The new overlay is limited to the t14 configuration. Pending: independent verifier, parent spot check, a separately authorized build and deployment, and runtime proof.

### L24 — Independent static adoption and tracking, 2026-10-29

Independent verifier 358 found no source blockers. Its candidate-vs-base probes matched the pinned base for source, buildPhase, installPhase, version and `dontPatchELF`, and matched the broker `drvPath`. These probes were adopted into the existing seven checks of `tests/t14-intune-tls.nix`, with no new cases or framework. This is a regression-adoption exception: the production behavior was already green, so no fresh RED is claimed. The independent baseline RED was two failing fields (`portalWrapsGioTlsProvider`, `wrapperNativeInputPresent`), and the candidate reached GREEN with all seven checks true. The parent reran the same focused command after `nix fmt` (0 changed) and `git diff --check` passed.

Limits: this is static evaluation only. No wrapped binary was built, and the GUI, device authentication, Edge sync and enrollment were not exercised. The portal-only change leaves the broker, Edge and root services unchanged, and Edge sync remains unverified. Build, deployment and runtime proof are pending separate authorization.

### L25 — Publish the TLS correction for deployment testing, 2026-10-29

User request verbatim: "tiens que hacer push para probar el depsliegue en t14 pues". Publish the four-path correction, regression test, docs and tracking on the existing branch; retain the previously requested normal master integration without Feature Flow, rebase, force-push or PR. This authorizes Git publication, not assistant deployment, enrollment or runtime changes. Remote feature HEAD still matches local `a0dae332`; fetched master has one additional RDP-shortcut commit touching only `darwin/home/remote-desktop.nix`. Commit the correction, merge that update and refresh the focused/target evaluations before normal push.

### L26 — TLS fix commit and publication checks, 2026-10-29

Fix commit `e4a6294415e90bc809ec5528bd3e7748dd7d01e7` contains exactly the four reviewed paths; hooks changed no bytes. Normal merge `e81afaba734b118eeb6ee004b00088287fa0a0e7` includes master `3e5a637402cebf902c2baff51c66ae85da33b492` without conflicts. The seven focused TLS checks, t14 ON/OFF toplevel evaluations, macm5 Darwin/Home Manager evaluations and `git diff --check` all passed. Existing context/deprecation warnings were nonfatal. This evidence-only follow-up prepares the authorized normal push; the confirmed remote result is stored in session memory. No build, deployment, enrollment or host mutation occurred.

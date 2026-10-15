# OpenCode V2 Migration Completion Specification

## ADDED Requirements

### Requirement: Reconciled Migration Ledger

Mandatory gates MUST be `proven`, `failed`, or `blocked`; code MUST NOT count as proof. Records MUST identify gate, host, action, result, and evidence. Blocked gates remain non-passing.

#### Scenario: Reconcile existing gates [hosts: rog, thinkcentre, t14, macm5]

- GIVEN predecessor tasks contain unchecked gates
- WHEN the completion ledger is produced
- THEN valid evidence is retained
- AND each unproven gate remains failed or blocked

#### Scenario: Dependency is unavailable [hosts: rog, thinkcentre, t14, macm5]

- GIVEN host, platform, funds, or BrowserMCP pairing is unavailable
- WHEN a mandatory gate is attempted
- THEN it is recorded `blocked` with reproducible evidence
- AND it is not represented as passing

### Requirement: Engram Lifecycle Parity

V2 MUST provide memory instructions, session attribution, prompt capture, save-tool session injection, passive Task-result capture, and compaction context with persistence guidance. JD-1 and JD-2 MUST receive focused tests and dual re-judgment.

#### Scenario: Persist an attributed interaction [hosts: rog, thinkcentre, t14, macm5]

- GIVEN a V2 Engram session
- WHEN a prompt, save tool, or Task result is processed
- THEN the prompt or observation is captured under that registered session
- AND memory guidance is present

#### Scenario: Compact a session [hosts: rog, thinkcentre, t14, macm5]

- GIVEN a V2 session with memory context
- WHEN compaction occurs
- THEN context and a save directive are injected
- AND parity is not accepted until both judges clear JD-1 and JD-2

### Requirement: Four-Host Operational Acceptance

Each host MUST pass gates for SDD/review, BrowserMCP, provider policy, and isolation/supervision. One host's evidence MUST NOT substitute for another's.

#### Scenario: Exercise SDD and review [hosts: rog, thinkcentre, t14, macm5]

- GIVEN V2 adapters register
- WHEN a full SDD cycle and review round-trip run
- THEN delegation, receipts, review, RTK, and Engram succeed
- AND V1 identity remains unchanged

#### Scenario: Exercise BrowserMCP [hosts: rog, thinkcentre, t14, macm5]

- GIVEN the supervised bridge and paired extension are available
- WHEN two workspaces call concurrently and the bridge restarts
- THEN one child serves both and both reconnect
- AND unpaired operation is reported blocked, never healthy

#### Scenario: Enforce provider policy [hosts: rog, thinkcentre, t14, macm5]

- GIVEN the six-provider policy is active
- WHEN allowed and denied requests are attempted
- THEN only allowed identifiers are selectable
- AND insufficient funds is blocked evidence, not query success

#### Scenario: Preserve isolation and supervision [hosts: rog, thinkcentre, t14, macm5]

- GIVEN V1 and V2 use separate roots and supervised V2 services
- WHEN configuration changes or V2 fails
- THEN V2 recovers without writing V1 state
- AND one-way credential seeding and project-config refusal remain enforced

### Requirement: Intentional Omissions

V2 MUST NOT reintroduce claude-auth, Warden, TUI pair, model-variants, multimodal, or V1 fields `logLevel`, `server`, `subagent_depth`, `whitelist`, and `blacklist`. JEV, model-level allowlisting, credential-collision repair, and code-work argument harmonization remain out of scope.

#### Scenario: Inspect generated V2 assets [hosts: rog, thinkcentre, t14, macm5]

- GIVEN V2 assets are generated
- WHEN omissions are inspected
- THEN none is emitted or treated as a defect

### Requirement: Explicit Cutover No-Go

The migration MUST remain incomplete and MUST NOT be archived or default while mandatory proof is failed, blocked, or absent. V1 MUST remain the isolated fallback unless every prerequisite passes and cutover is explicitly authorized.

#### Scenario: Mandatory proof is not passing [hosts: rog, thinkcentre, t14, macm5]

- GIVEN at least one mandatory gate is failed, blocked, or absent
- WHEN cutover readiness is assessed
- THEN the decision is `NO-GO`
- AND V2 remains opt-in while V1 stays available

#### Scenario: All prerequisites pass [hosts: rog, thinkcentre, t14, macm5]

- GIVEN every mandatory gate passes on each applicable host
- WHEN cutover readiness is assessed
- THEN explicit authorization is still required before changing defaults
- AND V1 rollback MUST remain possible

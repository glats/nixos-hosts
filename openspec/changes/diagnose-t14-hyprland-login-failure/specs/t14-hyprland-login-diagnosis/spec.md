# t14-hyprland-login-diagnosis Specification

## Purpose

Define the proof-first diagnosis behavior for t14 Hyprland login failure after `greetd` authentication, without assuming root cause or promoting any upstream fix.

## Requirements

### Requirement: Runtime Evidence First

The diagnosis flow MUST capture runtime evidence before changing local behavior whenever shell access after a failed login makes that practical. Evidence MUST distinguish observed facts from candidate explanations.

#### Scenario: [t14] Capture proof before edits

- GIVEN t14 has just failed after `greetd` authentication and shell or SSH access is available
- WHEN the diagnosis step runs
- THEN it MUST collect available `greetd`, user journal, relevant user-systemd state, and generated Hyprland startup evidence before any config edit
- AND it MUST record the evidence as facts, not as confirmed root cause

#### Scenario: [t14] Evidence is incomplete but still useful

- GIVEN some runtime sources are available but do not fully prove the candidate
- WHEN the diagnosis step records them
- THEN it MUST preserve the partial evidence and mark the remaining uncertainty explicitly

### Requirement: One Reversible Local Separator

If runtime evidence is unavailable or insufficient to prove or refute the candidate, the system MAY run one t14-local separator experiment. That experiment MUST be reversible, MUST stay local to `.nixos`, and MUST NOT include regreet restoration or any upstream `omarchy-nix` change.

#### Scenario: [t14] Run the separator only after proof is unavailable or insufficient

- GIVEN runtime evidence cannot be captured or cannot conclusively answer the candidate
- WHEN a separator experiment is prepared
- THEN it MUST be limited to disabling Home Manager Hyprland systemd integration and removing the local rescue `extraCommands` override
- AND it MUST leave `tuigreet` active and all upstream repositories unchanged

#### Scenario: [t14] Skip broader fixes during diagnosis

- GIVEN the separator experiment is in scope
- WHEN another change such as regreet restoration, greeter redesign, or upstream promotion is considered
- THEN the diagnosis flow MUST reject that broader change in this spec slice

### Requirement: Proof Outcome And Rollback

The diagnosis result MUST end in either stable post-auth login proof or conclusive refutation of the active candidate. Any local separator change MUST include explicit rollback criteria.

#### Scenario: [t14] Candidate supported by stable login

- GIVEN the local separator experiment is applied
- WHEN authentication completes and the user session remains stable after login
- THEN the result MUST be recorded as local proof for the candidate
- AND the next upstream or regreet work MUST remain a later separate change

#### Scenario: [t14] Candidate refuted or experiment regresses behavior

- GIVEN logs or the separator experiment fail to support the candidate
- WHEN the evidence shows the session still fails or points elsewhere
- THEN the result MUST record the candidate as unproven or refuted
- AND any local separator edit MUST be rolled back before expanding scope

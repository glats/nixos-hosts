# Evaluation Specification

## Purpose

Define requirements for evaluating and deciding on P1, P2, and P3 customization items after P0 restoration is complete.

## Requirements

### Requirement: P1 Item Evaluation

The system MUST evaluate all P1 items (caveman mode, nix-verify, persona rules) for restoration.

#### Scenario: Caveman mode evaluated

- GIVEN P0 restoration is complete
- WHEN caveman mode is evaluated
- THEN a decision is documented (restore, defer, or discard)
- AND the decision includes rationale

#### Scenario: Nix-verify evaluated

- GIVEN P0 restoration is complete
- WHEN nix-verify skill is evaluated
- THEN a decision is documented (restore, defer, or discard)
- AND the decision includes rationale

#### Scenario: Persona rules evaluated

- GIVEN P0 restoration is complete
- WHEN local persona rules are evaluated
- THEN each rule is evaluated individually
- AND a decision is documented for each rule

### Requirement: P2/P3 Item Evaluation

The system MUST evaluate all P2 and P3 items for restoration.

#### Scenario: P2 items evaluated

- GIVEN P1 evaluation is complete
- WHEN P2 items are evaluated
- THEN each item receives a decision (restore, defer, or discard)
- AND decisions are documented with rationale

#### Scenario: P3 items evaluated

- GIVEN P2 evaluation is complete
- WHEN P3 items are evaluated
- THEN each item receives a decision (restore, defer, or discard)
- AND decisions are documented with rationale

### Requirement: Decision Documentation

The system MUST document all restoration decisions in a comprehensive report.

#### Scenario: Restoration report generated

- GIVEN all evaluations are complete
- WHEN the documentation step runs
- THEN a report is generated listing all items
- AND each item shows its status (restored, deferred, discarded)
- AND the report includes rationale for each decision

#### Scenario: Deferred items tracked

- GIVEN items are marked as deferred
- WHEN the documentation is generated
- THEN deferred items are listed with reasons for deferral
- AND deferred items include criteria for future restoration

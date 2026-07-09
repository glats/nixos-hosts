# Delta for review-gates

## ADDED Requirements

### Requirement: RP-007 Policy File Source

The `sdd-review-policy.md` file SHALL be Nix-managed via `extraAssets` + `opencode.nix` deployment, replacing the previously manual placement at `~/.config/opencode/sdd-review-policy.md`. No behavioral change to the review gates themselves — the orchestrator reads the file from the same path. This requirement exists solely to document the source change.

#### Scenario: File present after rebuild

- GIVEN `nixos-build switch` completes
- WHEN orchestrator reads `~/.config/opencode/sdd-review-policy.md`
- THEN the file exists AND contains the review policy content

#### Scenario: Behavior unchanged

- GIVEN the policy file is now Nix-managed
- WHEN the orchestrator runs the Review Gate protocol
- THEN verdict resolution, binary decision presentation, and gate enforcement SHALL behave identically to before

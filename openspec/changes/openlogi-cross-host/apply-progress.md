# Apply Progress: OpenLogi on t14 and macm5

## Status

- Mode: Standard (strict TDD disabled by `openspec/config.yaml`)
- Workload: Single focused change; `ask-on-risk`; low 70–150 authored-line forecast
- Authorization: Implementation and verification only; no activation, deployment, commit, push, service operation, remote write, or device mutation
- Scope guard: Unrelated dirty work was preserved. Product edits are limited to the five design paths.

## Completed Tasks

All assigned tasks 1.1–4.1 are complete.

### Foundation and RED assertions

- 1.1 Baseline status and lock snapshot were captured from the prechange Git tree. Existing unrelated modifications and untracked OpenSpec work were preserved; only the five scoped product paths were changed.
- 1.2 Scoped evaluation assertions passed for t14 ownership, macm5 cask ownership, rog/thinkcentre exclusion, unchanged Homebrew rolling policy, and absence of custom mappings or additional Darwin launchd configuration. The design threat rows for documentation, repository selection, commit, push, and PR are N/A and require no RED tests.
- 1.3 Parsed lock comparison found only the root OpenLogi edge plus new `openlogi` and `rust-overlay` nodes. The OpenLogi lock revision is `7a9d092a7dda0cb3b7ec18ada4424d681fca65ca`; its nixpkgs input follows the repository root.

### Implementation

- 2.1 Added the exact OpenLogi v0.8.11 input and generated its narrow lock closure without updating unrelated pins.
- 2.2 Added `linux/system/hardware/openlogi.nix`, importing `inputs.openlogi.nixosModules.default` and setting only `programs.openlogi.enable = true`.
- 2.3 Added one explicit import only to `hosts/t14/default.nix`; rog, thinkcentre, builders, shared Home Manager lists, and generated hardware remain untouched.
- 2.4 Added only the `openlogi` cask; existing Homebrew auto-update, upgrade, cleanup, and native Login Item ownership remain unchanged.

### Verification and recovery

- 3.1 `nix fmt -- flake.nix linux/system/hardware/openlogi.nix hosts/t14/default.nix darwin/system/homebrew.nix`: passed, no formatting changes. `nix flake check --no-build` from a non-Git temporary copy containing the untracked module: passed; direct checkout check was blocked only because Git flakes exclude untracked source.
- 3.2 t14 evaluation passed. Package membership and udev membership both contain OpenLogi. Agent assertions passed: `wantedBy`, `after`, and `partOf` are `["graphical-session.target"]`; `ExecStart` is the package-qualified `/bin/openlogi-agent`. macm5 cask evaluation contains `openlogi` and preserves `autoUpdate = true`, `upgrade = true`, `cleanup = "uninstall"`. rog and thinkcentre toplevel evaluations passed and have no OpenLogi import.
- 3.3 Exact package derivation evaluation passed at `/nix/store/aizw4cs34a1jm7l6bl86fkpjwhyhj6yq-openlogi-0.8.11.drv`. The exact build was started as a read-only `nix build` in the temporary copy and remains pending until its completion event; no native Darwin build was attempted on Linux and no native evidence is claimed.
- 3.4 Deployment, activation, service lifecycle, permissions, Hyprland foreground behavior, macOS privacy grants, persistence/backups, and hardware probes remain deferred. K780 and G305 controls are unproven; the probable G502 LIGHTSPEED identity and remapping/profile support remain unconfirmed.
- 4.1 Recovery remains declarative-only: retain known-good generations, the signed macOS artifact, and matching config backups before deployment; stop the owned agent before restoring another manager; separately restore mutable config/device state and remove unwanted Login Item/TCC grants. Nix rollback does not restore Homebrew versions.

## Work Unit Evidence

| Evidence | Exact result |
|---|---|
| Focused test command | `nix flake check --no-build` from `/home/glats/.local/opencode-v2/tmp/opencode/openlogi-cross-host-check`: passed; direct checkout attempt failed only on untracked-source visibility. |
| Runtime harness | N/A: deployment and native sessions were explicitly forbidden; no runtime or hardware mutation was performed. |
| Rollback boundary | Revert only `flake.nix`, `flake.lock`, `linux/system/hardware/openlogi.nix`, `hosts/t14/default.nix`, and `darwin/system/homebrew.nix`. |

## Deviations and Pending Evidence

- No implementation deviation from design.
- Native Darwin build/install and all postdeployment lifecycle, privacy, persistence, and hardware gates are intentionally deferred and must not be reported as passed.
- The exact Linux build was launched but its completion result is pending; independent verification should consume the shell completion event before treating compilation as proven.

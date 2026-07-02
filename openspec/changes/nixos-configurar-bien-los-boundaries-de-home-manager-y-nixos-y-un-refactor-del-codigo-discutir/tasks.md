# Tasks: Flake.nix Home Manager Boundary Refactor

**Change**: nixos-configurar-bien-los-boundaries-de-home-manager-y-nixos-y-un-refactor-del-codigo-discutir
**Scope**: bounded to `flake.nix` only
**Source artifacts**: `proposal.md`, `specs/linux-hm-composition-alignment/spec.md`, `design.md`

## Review Workload Forecast

Decision needed before apply: No
Chained PRs recommended: No
400-line budget risk: Low

Forecast note: this bounded refactor is expected to stay well under the default review budget because it touches one file and keeps the change mechanically localized.

## Task Breakdown

### 1. Update the misleading `linuxHomeModules` comment block
- [x] Edit the comment block in `flake.nix` so it no longer claims `linuxHomeModules` is the mechanism keeping Linux Home Manager paths in sync.
- [x] Replace that claim with accurate wording that `linuxHomeModules` remains for the Darwin/multi-platform helper path and is not the Linux ownership source after this refactor.
- [x] Keep the comment concise and aligned with the actual control flow in `mkHomeConfig`.

### 2. Replace the standalone `rog` Home Manager entry
- [x] Replace the `homeConfigurations.rog` standalone composition in `flake.nix` with a direct `home-manager.lib.homeManagerConfiguration` call.
- [x] Point the module list at `hosts/rog/home/modules.nix` instead of appending ad-hoc modules to `linuxHomeModules`.
- [x] Preserve the required `extraSpecialArgs` expected by the imported modules.

### 3. Replace the standalone `thinkcentre` Home Manager entry
- [x] Replace the `homeConfigurations.thinkcentre` standalone composition in `flake.nix` with the same direct `home-manager.lib.homeManagerConfiguration` pattern.
- [x] Point the module list at `hosts/thinkcentre/home/modules.nix`.
- [x] Preserve the required `extraSpecialArgs` expected by the imported modules.

### 4. Preserve and document the `t14` special case
- [x] Keep the `homeConfigurations.t14` path unchanged.
- [x] Add or retain a nearby comment that explicitly marks `t14` as an intentional exception to the Linux ownership-source rule.
- [x] Ensure the comment makes it clear this exception is deliberate, not an omission.

### 5. Align the change with the planning artifacts before apply
- [x] Re-read the proposal, spec, and design to confirm the tasks still match the bounded `flake.nix` scope.
- [x] Confirm the task list stays limited to the four intended edit areas: comment block, `rog`, `thinkcentre`, and `t14` annotation.
- [x] Record any mismatch between tasks and planning artifacts before implementation begins.

### 6. Verification tasks for the apply phase
- [x] Run `format-nix` after the `flake.nix` edit.
- [x] Run `nix flake check --no-build` to verify flake evaluation.
- [x] Confirm the touched lines remain within the bounded `flake.nix` scope and no unrelated files are modified.
- [x] If evaluation exposes a mismatch with the plan, update the planning artifact before proceeding.

## Completion Checklist

- [x] `flake.nix` comment block is no longer misleading
- [x] `homeConfigurations.rog` uses the per-host modules source
- [x] `homeConfigurations.thinkcentre` uses the per-host modules source
- [x] `t14` exception is documented and preserved
- [x] Planning artifacts still match the bounded implementation plan
- [x] Verification passes

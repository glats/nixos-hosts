# Tasks: Two-layer fix for Home Manager activation gap

## Phase 1: Apply

- [x] 1.1 Make opencode activation scripts self-healing in `shared/opencode.nix`
  - Replace early-exit guard with `mkdir -p` in `makeOpencodeConfigMutable-default`
  - Replace early-exit guard with `mkdir -p` in `setupOpencodePluginRuntime-default`
  - Replace early-exit guard with `mkdir -p` in `syncOpencodeSkillsToOpenfang-default`
- [x] 1.2 Add post-switch HM activation hook to `bin/nixos-build` `switch` case
- [x] 1.3 Add post-switch HM activation hook to `bin/nixos-build` `upgrade` case
- [x] 1.4 Add post-switch HM activation hook to `bin/nixos-build` `safe` case

## Verification

- [x] `nix flake check --no-build` passes
- [x] `format-nix` shows no changes required

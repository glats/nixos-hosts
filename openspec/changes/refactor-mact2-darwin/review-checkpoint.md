# Review Checkpoint: refactor-mact2-darwin

**Status**: Not started
**Created**: 2026-07-06

## Pre-review Checklist

Before requesting review, the apply phase must verify:

### Structural Correctness
- [ ] `darwin/default.nix` no longer imports individual `darwin/*.nix` files -- only `modules/darwin/profiles/base.nix` and HM/user config
- [ ] `modules/darwin/profiles/base.nix` mirrors the pattern from `modules/profiles/base.nix` (pure import aggregator, no inline config)
- [ ] All moved files have correct relative import paths for their new location
- [ ] `modules/darwin/system/nix.nix` contains all nix config previously split across `darwin/default.nix` and `darwin/cachix.nix`

### specialArgs Safety
- [ ] `lib/mkDarwinHost.nix` no longer contains `home-manager.extraSpecialArgs` inline block
- [ ] `darwin/default.nix` passes `inputs`, `self`, `primaryUser`, `javaVersion` in `home-manager.extraSpecialArgs`
- [ ] `mkDarwinHost.nix` and `mkHost.nix` follow the same pattern: builder sets only `specialArgs`, not subsystem config

### GPG/Ghostty Correctness
- [ ] `shared/gpg.nix` contains the `importKey` function (byte-identical to both current versions)
- [ ] `home-linux/gpg.nix` and `home-darwin/gpg.nix` both import `shared/gpg.nix` and add only their platform-specific packages
- [ ] `home-darwin/ghostty.nix` uses `programs.ghostty` (not `home.file`) with `themes.nix-colors` palette attrset
- [ ] macOS-specific ghostty keys (`macos-option-as-alt`) are preserved as overrides

### Build Verification
- [ ] `nix flake check --no-build darwinConfigurations.mact2` exits 0
- [ ] `nix flake check --no-build` exits 0 for all NixOS hosts (rog, thinkcentre, t14)
- [ ] `format-nix` produces no uncommitted changes

### Review Budget
- [ ] `git diff --stat main...HEAD` shows total changed lines under 400
- [ ] If over 400: chained PR slices documented in `tasks.md`

## Reviewer Focus Areas

1. **`modules/darwin/profiles/base.nix`** -- Does it match the `modules/profiles/base.nix` pattern? Is it a pure import aggregator?
2. **`darwin/default.nix`** -- After refactor, does it clearly separate system modules (imported via profile) from host-specific concerns (HM, users, environment)?
3. **`lib/mkDarwinHost.nix`** -- Is the `home-manager.extraSpecialArgs` block properly removed? Does the builder now match `mkNixosHost` structure?
4. **`shared/gpg.nix`** -- Is the extracted function correct for both platforms? Are secrets paths still valid?
5. **`home-darwin/ghostty.nix`** -- Does the `programs.ghostty` migration preserve palette colors, keybinds, and macOS-specific settings?

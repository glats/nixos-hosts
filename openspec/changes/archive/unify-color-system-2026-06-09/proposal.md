# Proposal: Unify Color System

## Intent

The color system has four inconsistencies that make `shared/palette.nix` the nominal source of truth but not the actual one. Hardcoded hex values, duplicated palette definitions, platform-specific color drift, and duplicated helper functions all create maintenance risk and violate the single-source-of-truth principle.

## Scope

### In Scope
- Replace hardcoded hex values in `home-linux/theme.nix` lines 26-43 with `config.colorScheme.palette` references
- Replace the duplicated `p` attrset in `modules/desktop/kmscon.nix` lines 13-30 with a direct import of `shared/palette.nix`
- Fix `home-darwin/ghostty.nix` line 25: change `color8` from `base04` to `base03` to match `home-linux/ghostty.nix` and the base16 standard
- Extract `hexToRgb`, `doubleHex`, and `byteDoubleHex` from `home-linux/mate.nix` and `modules/desktop/kmscon.nix` into a new shared library `lib/colors.nix`
- Update all consumers to import `lib/colors.nix`

### Out of Scope
- Changing actual color values in `shared/palette.nix`
- Adding new color schemes or migrating to a nix-colors built-in theme
- Refactoring color usage in files not mentioned above

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- None

## Approach

1. Create `lib/colors.nix` with a unified `hexToRgb` implementation (the `mate.nix` version is preferred because it handles `lib.fromHexString` properly) and `doubleHex`/`byteDoubleHex`.
2. Update `home-linux/mate.nix` to import `lib/colors.nix` and remove its local `hexToRgb`, `doubleHex`, `byteDoubleHex` definitions.
3. Update `modules/desktop/kmscon.nix` to import `shared/palette.nix` and `lib/colors.nix`, removing its local `p` and `hexToRgb`.
4. Update `home-linux/theme.nix` to interpolate palette values into the GTK CSS string.
5. Update `home-darwin/ghostty.nix` to change `color8` from `base04` to `base03`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `home-linux/theme.nix` | Modified | Remove hardcoded hex values, reference palette |
| `modules/desktop/kmscon.nix` | Modified | Import `shared/palette.nix` and `lib/colors.nix` |
| `home-darwin/ghostty.nix` | Modified | Fix color8 to base03 |
| `home-linux/mate.nix` | Modified | Import `lib/colors.nix`, remove local helpers |
| `lib/colors.nix` | New | Shared color helper functions |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `hexToRgb` implementations differ in behavior | Low | Verify both produce the same RGB output for all palette values before replacing |
| `kmscon.nix` import of `shared/palette.nix` fails at evaluation | Low | Test with `nix flake check` after the change |
| `home-linux/theme.nix` CSS string interpolation breaks GTK CSS syntax | Low | Check that interpolated values produce valid `#RRGGBB` format |
| Darwin host color shift after color8 fix | Med | Acceptable — this is a correction to match the standard and the Linux host |

## Rollback Plan

Revert the commit. All changes are in separate files; a single `git revert` restores the previous hardcoded values and local definitions. No state migration or data loss.

## Dependencies

- None

## Success Criteria

- [ ] `home-linux/theme.nix` contains zero hardcoded hex values referencing palette colors
- [ ] `modules/desktop/kmscon.nix` imports `shared/palette.nix` instead of defining its own `p` attrset
- [ ] `home-linux/ghostty.nix` and `home-darwin/ghostty.nix` use identical values for `color8`
- [ ] `lib/colors.nix` exists and is imported by `home-linux/mate.nix` and `modules/desktop/kmscon.nix`
- [ ] `nix flake check` passes after all changes

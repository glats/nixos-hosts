# Proposal: screenshot-omarchy-nix

## Intent

The `omarchy-nix` upstream module ships screenshot scripts (`omarchy-capture-screenshot`, `omarchy-capture-text-extraction`, `omarchy-capture-screenrecording`) and Hyprland keybindings, but three runtime dependencies are missing from the module's own package list. Pressing the screenshot keybinding fails silently because `grim`, `wl-copy`, and `tesseract` are not on `$PATH`. This change adds the missing packages **upstream** in `glats/omarchy-nix` so all consumers (including `nixos-hosts`) get them automatically.

## Scope

### In Scope (Repo: `glats/omarchy-nix`)
- Add `grim`, `wl-clipboard`, `tesseract` to `modules/packages.nix` under the existing capture-related packages
- Commit and push to `glats/omarchy-nix` main branch

### In Scope (Repo: `nixos-hosts`)
- Bump the `omarchy-nix` flake input to point to the new upstream commit
- `flake.lock` auto-updates; no manual code changes needed

### Out of Scope
- Additional OCR languages (upstream hardcodes `-l eng`)
- Adding `v4l-utils` (webcam overlay, not called by screenshot scripts)
- Other hosts (rog, thinkcentre — no omarchy-nix)

## Capabilities

### New Capabilities
None — this is a dependency completion, not a new feature.

### Modified Capabilities
- `glats/omarchy-nix/modules/packages.nix`: 3 packages added to existing list

## Approach

**Fix upstream, consume downstream.** The `nixos-hosts` repo should remain a simple consumer of omarchy-nix without local patches.

1. Add missing packages to `glats/omarchy-nix/modules/packages.nix` (alongside existing `slurp`, `satty`, `hyprshot`, etc.)
2. Push to `glats/omarchy-nix` main
3. In `nixos-hosts`: `nix flake lock --update-input omarchy-nix` (or update rev pin if present)

Packages:
| Package | Provides | Called by |
|---------|----------|-----------|
| `grim` | `grim` binary | `omarchy-capture-screenshot` line 144 |
| `wl-clipboard` | `wl-copy`, `wl-paste` | Clipboard pipe in screenshot scripts |
| `tesseract` | OCR engine + `eng.traineddata` (bundled in nixpkgs) | `omarchy-capture-text-extraction` |

## Affected Areas

| Repo | File | Impact |
|------|------|--------|
| `glats/omarchy-nix` | `modules/packages.nix` | Modified — add 3 packages |
| `nixos-hosts` | `flake.lock` | Auto-updated — no manual changes |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `tesseract` bloat | Low | ~30MB; acceptable for a laptop |
| OCR language hardcoded to `eng` | N/A | Out of scope; flag for future |
| Missing `v4l-utils` for webcam overlay | N/A | Out of scope; separate change |

## Dependencies

- `glats/omarchy-nix` repo — user has full clone+push access (AGENTS.md)

## Success Criteria

- [ ] `grim`, `wl-clipboard`, `tesseract` appear in omarchy-nix `modules/packages.nix`
- [ ] `nix flake check --no-build` passes on `nixos-hosts` after flake bump
- [ ] `,` + `PRINT` opens slurp region selector on t14
- [ ] `grim` captures the selected region and opens satty
- [ ] `wl-copy` places the screenshot on clipboard
- [ ] Text extraction produces OCR output via tesseract

## Changelog

- **v1** (original): Proposed local fix in `hosts/t14/home/omarchy.nix`
- **v2** (corrected): Fix in upstream `glats/omarchy-nix`; nixos-hosts only bumps flake

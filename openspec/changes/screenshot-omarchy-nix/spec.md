# Spec: screenshot-omarchy-nix

## Summary

Add 3 missing runtime packages (`grim`, `wl-clipboard`, `tesseract`) to the omarchy-nix flake module so the screenshot capture pipeline works end-to-end. The consumer repo (nixos-hosts) only needs a flake.lock bump.

**Key discovery**: `tesseract-data-eng` is NOT a separate nixpkgs package — English traineddata is bundled with `tesseract` by default (the derivation build phase enforces `eng.traineddata` presence at build time). Only 3 packages are needed, not 4.

## Affected Repos

| Repo | File | Change |
|------|------|--------|
| `glats/omarchy-nix` | `modules/packages.nix` | Add `grim`, `wl-clipboard`, `tesseract` to `systemPackages` under `# Screenshot and recording` section |
| `glats/nixos-hosts` | `flake.lock` | Auto-updated via `nix flake update omarchy-nix` |

## Requirements

### R1: Screenshot capture pipeline

The omarchy-nix module MUST provide all binaries required by `omarchy-capture-screenshot`.

#### Scenario: Region screenshot with clipboard copy

- GIVEN t14 with omarchy-nix enabled
- WHEN user presses `,` + `PRINT`
- THEN `slurp` opens for region selection
- AND `grim` captures the selected region to `$OUTPUT_DIR`
- AND `wl-copy` places the image on the clipboard
- AND `satty` opens for annotation when user clicks the notification

#### Scenario: Screenshot to clipboard only (slurp processing)

- GIVEN the screenshot script is invoked with `PROCESSING=copy`
- WHEN a region is selected
- THEN `grim` pipes to stdout and `wl-copy` receives the image directly

### R2: OCR text extraction

The omarchy-nix module MUST provide all binaries required by `omarchy-capture-text-extraction`.

#### Scenario: English text extraction from screen region

- GIVEN t14 with omarchy-nix enabled
- WHEN user invokes `omarchy-capture-text-extraction`
- AND text is present in the selected screen region
- THEN `grim` captures the region to stdout
- AND `tesseract` extracts English text via `stdin`/`stdout` with `--oem 1 --psm 6 -l eng`
- AND `wl-copy` places the extracted text on the clipboard

#### Scenario: Tesseract English data available

- GIVEN `tesseract` is installed via omarchy-nix
- WHEN `tesseract --list-langs` is run
- THEN `eng` appears in the listed languages (bundled by nixpkgs, no separate data package needed)

### R3: Screen recording (verify no missing deps)

The omarchy-nix module MUST provide all binaries required by `omarchy-capture-screenrecording`.

#### Scenario: Screen recording start and stop

- GIVEN t14 with omarchy-nix enabled
- WHEN user presses `ALT` + `PRINT`
- THEN `gpu-screen-recorder` starts recording the selected region or monitor
- AND pressing `ALT` + `PRINT` again stops recording and saves the video
- AND `ffmpeg` post-processes the recording (trim + audio normalization)

### R4: Consumer repo remains clean

The nixos-hosts repo MUST NOT contain local patches or `home.packages` overrides for screenshot dependencies.

#### Scenario: Flake input update provides all deps

- GIVEN the omarchy-nix flake input in nixos-hosts points to a commit with the new packages
- WHEN the user runs `nix flake update omarchy-nix`
- THEN `grim`, `wl-copy`, and `tesseract` are available on `$PATH` without any local config changes

#### Scenario: No home.packages workaround in nixos-hosts

- GIVEN the screenshot fix is deployed via upstream omarchy-nix
- WHEN inspecting `hosts/t14/home/omarchy.nix`
- THEN no `home.packages` block exists for `grim`, `wl-clipboard`, or `tesseract`

## Non-Requirements

- Changing OCR language from hardcoded `-l eng` (separate change)
- Adding screenshot keybindings or scripts (exist upstream)
- Changing the screenshot editor from `satty`
- Multi-host support (only t14 uses omarchy-nix)

## Package Mapping

| Package (nixpkgs attr) | Provides | Called by script |
|------------------------|----------|-----------------|
| `grim` | `grim` binary | `omarchy-capture-screenshot` (L130, L138), `omarchy-capture-text-extraction` (L21) |
| `wl-clipboard` | `wl-copy`, `wl-paste` | All three capture scripts |
| `tesseract` | `tesseract` + `eng.traineddata` | `omarchy-capture-text-extraction` (L21) |

## Rollback

Remove the 3 packages from `modules/packages.nix` in omarchy-nix and bump flake.lock in nixos-hosts. Zero side effects — no other module depends on these packages.

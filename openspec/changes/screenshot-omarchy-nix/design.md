# Design: screenshot-omarchy-nix

## Technical Approach

Fix the broken screenshot pipeline by adding 3 missing runtime packages (`grim`, `wl-clipboard`, `tesseract`) to the upstream omarchy-nix module. The consumer repo (nixos-hosts) only bumps its flake input — no local patches needed.

This is a **dependency completion** change: scripts and keybindings already exist upstream, but the packages they shell-out to were never declared in the module's `systemPackages`.

## Architecture Decisions

### Decision: Fix upstream, not downstream

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Add packages to `hosts/t14/home/omarchy.nix` | Quick local fix, but duplicates upstream responsibility | **Rejected** |
| Add packages to `glats/omarchy-nix/modules/packages.nix` | Proper fix; all consumers benefit; single source of truth | **Chosen** |

**Rationale**: omarchy-nix owns the scripts and keybindings — it must own the dependencies. The nixos-hosts repo should remain a clean consumer.

### Decision: Insert into existing "Screenshot and recording" section

| Option | Tradeoff | Decision |
|--------|----------|----------|
| New section `# Screenshot dependencies` | Adds visual separation but fragments a coherent group | **Rejected** |
| Add to existing `# Screenshot and recording` block | Keeps all capture-related packages together | **Chosen** |

**Rationale**: The existing section already has `satty`, `slurp`, `wf-recorder`, `gpu-screen-recorder` — these are the exact tools the 3 new packages complement.

### Decision: Commit directly to main

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Branch + PR | Adds review overhead for a 3-line package addition | **Rejected** |
| Direct commit to main | Fast; owner has full push access; conventional commit style | **Chosen** |

**Rationale**: The repo uses conventional commits (`fix(...)`, `feat(...)`). This is a `fix(packages)` change — small, self-contained, low risk.

## Data Flow

```
User keybinding (,+PRINT)
    │
    ▼
Hyprland dispatches omarchy-capture-screenshot
    │
    ├── slurp (region select) ── already in packages.nix ✓
    ├── grim (capture) ──────── MISSING → ADD grim
    ├── wl-copy (clipboard) ─── MISSING → ADD wl-clipboard
    └── satty (annotate) ────── already in packages.nix ✓

User keybinding (text extraction)
    │
    ▼
omarchy-capture-text-extraction
    │
    ├── grim (capture to stdout) ── MISSING → ADD grim
    ├── tesseract (OCR, -l eng) ── MISSING → ADD tesseract
    └── wl-copy (text to clip) ─── MISSING → ADD wl-clipboard
```

## File Changes

| File | Repo | Action | Description |
|------|------|--------|-------------|
| `modules/packages.nix` | `glats/omarchy-nix` | Modify | Add `grim`, `wl-clipboard`, `tesseract` after `slurp` (line 41) |
| `flake.lock` | `glats/nixos-hosts` | Auto-update | Bump omarchy-nix rev via `nix flake lock --update-input omarchy-nix` |

### Exact Edit: `modules/packages.nix`

**Current** (lines 37–42):
```nix
    # Screenshot and recording
    satty
    wf-recorder
    gpu-screen-recorder
    slurp
    hyprland-preview-share-picker  # Custom package
```

**After edit**:
```nix
    # Screenshot and recording
    satty
    wf-recorder
    gpu-screen-recorder
    slurp
    grim
    wl-clipboard
    tesseract
    hyprland-preview-share-picker  # Custom package
```

Insert 3 lines after `slurp` (line 41), before `hyprland-preview-share-picker` (line 42).

## Interfaces / Contracts

No new interfaces. The 3 packages expose standard binaries already expected by existing scripts:

| Package | Binaries added to `$PATH` |
|---------|--------------------------|
| `grim` | `grim` |
| `wl-clipboard` | `wl-copy`, `wl-paste` |
| `tesseract` | `tesseract` (with bundled `eng.traineddata`) |

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build (omarchy-nix) | Flake evaluates without errors | `nix flake check` in omarchy-nix repo |
| Build (nixos-hosts) | Flake evaluates after input bump | `nix flake check --no-build` in nixos-hosts |
| Runtime | Screenshot keybinding works | `,` + `PRINT` → slurp → grim → satty on t14 |
| Runtime | OCR extraction works | Text extraction keybinding → tesseract → wl-copy |
| Runtime | Recording still works | `ALT` + `PRINT` → gpu-screen-recorder (no regression) |

## Commit & Rollout Plan

### Step 1: Upstream commit (glats/omarchy-nix)

```bash
# In /home/glats/repos/omarchy-nix
# Edit modules/packages.nix — add 3 lines after slurp
nix fmt -- modules/packages.nix    # format
nix flake check                     # verify evaluation
git add modules/packages.nix
git commit -m "fix(packages): add grim, wl-clipboard, tesseract for screenshot pipeline"
git push origin main
```

### Step 2: Downstream bump (glats/nixos-hosts)

```bash
# In /home/glats/.nixos
nix flake lock --update-input omarchy-nix
nix flake check --no-build          # verify
# Then: nixos-build (when ready to deploy)
```

### Step 3: Deploy & verify

```bash
nixos-build                         # build + switch on t14
# Test: ,+PRINT, text extraction, ALT+PRINT
```

## Migration / Rollout

No migration required. Adding packages to `systemPackages` is purely additive — zero risk of breaking existing functionality. Rollback is trivial: remove the 3 lines and bump flake.lock back.

## Open Questions

- None.

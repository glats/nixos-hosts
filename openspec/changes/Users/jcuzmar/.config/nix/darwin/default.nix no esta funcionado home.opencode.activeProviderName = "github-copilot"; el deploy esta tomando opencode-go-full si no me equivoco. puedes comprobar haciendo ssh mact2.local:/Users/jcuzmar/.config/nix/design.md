# Design: Fix mact2 OpenCode provider drift (darwin vs. standalone HM)

> **One sentence**: Eliminate silent provider regression on mact2 by propagating the
> `github-copilot` override into `homeConfigurations.mact2` so both deployment paths evaluate
> identically, while keeping `darwin/default.nix` as the single point of truth for the override
> value.

---

## Quick Reference

| Question | Answer |
|----------|--------|
| Root cause | `homeConfigurations.mact2` does not inherit the `github-copilot` override that `darwin/default.nix` sets for the nix-darwin path |
| Fix scope | `flake.nix` only (1 line change) |
| Source of truth | `darwin/default.nix` line 56 (unchanged) |
| New file needed? | No — inline module in `flake.nix` is sufficient |
| `mkForce` required? | No — plain assignment wins over `mkDefault` |
| Flake check impact | Passing (one target fixed, no others touched) |

---

## Technical Approach

### The problem in two evaluations

```
# Nix-darwin path — CORRECT today
nix eval --raw .#darwinConfigurations.mact2.config.home-manager.users.jcuzmar.home.opencode.activeProviderName
# => github-copilot

# Standalone HM path — WRONG today (causes runtime drift)
nix eval --raw .#homeConfigurations.mact2.config.home.opencode.activeProviderName
# => opencode-go-medium   <-- regression when `hms` runs last
```

### Why this happens

`darwinConfigurations.mact2` is built via `mkDarwinHost` → `darwin/default.nix` which sets:

```nix
home-manager.users.${primaryUser}.home.opencode.activeProviderName = "github-copilot";
```

`homeConfigurations.mact2` is built via `baseHomeConfig "mact2" "x86_64-darwin" "jcuzmar"` which
calls `mkHomeConfig`. That function appends only `darwinHomeModules` + the supplied `extraModules`
list (`[ ./home-darwin ]`). It does NOT import `darwin/default.nix`, so the override is never
applied and the option falls back to its `mkDefault "opencode-go-medium"` value.

When `home-manager switch --flake .#mact2` runs (the `hms` alias on mact2), HM writes the
`opencode.json` with medium-tier model assignments, overwriting whatever `darwin-rebuild` had
previously deployed.

### Chosen approach: inline override module in `flake.nix`

The proposal's preferred approach (Option A: inline module in `extraModules`) is confirmed as
optimal by codebase inspection.

**Why inline over a shared per-host module file:**

| Criterion | Inline module in `flake.nix` | `hosts/mact2/home/provider.nix` |
|-----------|------------------------------|----------------------------------|
| File surface | No new file | New file + import in `flake.nix` |
| Source of truth fragmentation | Single string in `flake.nix` next to the target | Two places: new file + value in `darwin/default.nix` |
| Precedent in repo | `t14` inline omarchy settings in `homeConfigurations.t14` | Used for Linux per-host module ownership |
| Implementation effort | 1-line change in `flake.nix` | New file + 1-line change |
| Drift vector | Only `darwin/default.nix` can drift from inline | Both files can drift from each other |

For a single string override (`"github-copilot"`), a new module file adds indirection without
benefit. The inline module is the minimal, idiomatic fix.

**Why not remove `homeConfigurations.mact2`:**

The `hms` alias (`home-manager switch --flake .#mact2`) is a valid and commonly used workflow on
Darwin. Removing the target would silently break that alias. The inline fix is lower risk.

**Why `mkForce` is NOT needed:**

`activeProviderName` is defined with `default = lib.mkDefault "opencode-go-medium"`. A plain
assignment in a module wins over `mkDefault` via NixOS module merge priority without `mkForce`.
This is the same mechanism already used in `darwin/default.nix`. Confirmed from prior SDD work
(`sdd/opencode-go-per-host-config`).

---

## Architecture Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D1 | Inline override module in `flake.nix` `extraModules` for `homeConfigurations.mact2` | Minimal change, no new file, consistent with t14 pattern for standalone overrides |
| D2 | `darwin/default.nix` is the authoritative source; `flake.nix` inline duplicates the string | Acceptable duplication: two-line comment documents the relationship and prevents silent drift |
| D3 | Do NOT refactor `darwin/default.nix` to import a shared file | Would expand scope unnecessarily; the fix must be surgical |
| D4 | Do NOT add `mkForce` | Plain assignment is sufficient; `mkForce` is reserved for override-of-override conflicts |
| D5 | Do NOT remove `homeConfigurations.mact2` | `hms` alias relies on it; removing breaks the standalone workflow |

---

## Data Flow

### Before fix

```
darwin-rebuild switch --flake .#mact2
  └─> mkDarwinHost { hostname = "mact2"; }
        └─> darwin/default.nix
              └─> home.opencode.activeProviderName = "github-copilot"  [CORRECT]
                    └─> opencode.json: github-copilot/... models

home-manager switch --flake .#mact2
  └─> baseHomeConfig "mact2" "x86_64-darwin" "jcuzmar" [ ./home-darwin ]
        └─> darwinHomeModules ++ [ ./home-darwin ]
              └─> shared/opencode.nix: mkDefault "opencode-go-medium"  [REGRESSION]
                    └─> opencode.json: opencode-go/... models (overwrites above)
```

### After fix

```
darwin-rebuild switch --flake .#mact2
  └─> mkDarwinHost { hostname = "mact2"; }
        └─> darwin/default.nix
              └─> home.opencode.activeProviderName = "github-copilot"  [CORRECT]
                    └─> opencode.json: github-copilot/... models

home-manager switch --flake .#mact2
  └─> baseHomeConfig "mact2" "x86_64-darwin" "jcuzmar"
        [ ./home-darwin
          { home.opencode.activeProviderName = "github-copilot"; }  # <-- NEW
        ]
        └─> plain assignment wins over mkDefault
              └─> opencode.json: github-copilot/... models  [NOW CORRECT]
```

---

## File Changes

| File | Change type | Description |
|------|-------------|-------------|
| `flake.nix` | Edit (1 line added + 3 comment lines) | Extend `extraModules` for `homeConfigurations.mact2` with inline override module |

**No other files are touched.** In particular:
- `darwin/default.nix` — unchanged (already correct)
- `shared/opencode.nix` — unchanged
- `shared/opencode/providers*.nix` — unchanged
- `home-darwin/shared-modules.nix` — unchanged
- `hosts/mact2/default.nix` — unchanged

### Exact change to `flake.nix` (line 304)

**Before:**

```nix
mact2 = baseHomeConfig "mact2" "x86_64-darwin" "jcuzmar" [
  # Include home-darwin/default.nix so the standalone
  # home-manager build for mact2 picks up the per-host base
  # config (home.username, home.homeDirectory, etc.) on top of
  # the canonical module list from `darwinHomeModules`.
  ./home-darwin
];
```

**After:**

```nix
mact2 = baseHomeConfig "mact2" "x86_64-darwin" "jcuzmar" [
  # Include home-darwin/default.nix so the standalone
  # home-manager build for mact2 picks up the per-host base
  # config (home.username, home.homeDirectory, etc.) on top of
  # the canonical module list from `darwinHomeModules`.
  ./home-darwin
  # Mirror the provider override from darwin/default.nix line 56 so that
  # `home-manager switch --flake .#mact2` produces the same opencode.json
  # as `darwin-rebuild switch --flake .#mact2`. Keep in sync manually.
  { home.opencode.activeProviderName = "github-copilot"; }
];
```

---

## Interfaces

### Option under change

```
home.opencode.activeProviderName
  type:    types.str
  default: lib.mkDefault "opencode-go-medium"
  defined: shared/opencode.nix:322-330
```

This option is a custom HM option defined locally. It is NOT an upstream home-manager option.
Plain assignment in any module wins over `mkDefault`.

### Evaluation interface (verification commands)

```bash
# Must return "github-copilot" after fix
nix eval --raw .#homeConfigurations.mact2.config.home.opencode.activeProviderName

# Must still return "github-copilot" (regression guard)
nix eval --raw .#darwinConfigurations.mact2.config.home-manager.users.jcuzmar.home.opencode.activeProviderName
```

---

## Testing Strategy

No automated test runner exists for Nix configurations in this repo (strict_tdd: false from prior
SDD work). Verification is done via `nix eval` and `nix flake check --no-build`.

### Verification steps (in order)

1. `nix flake check --no-build` — must exit 0 (no structural error introduced)
2. `nix eval --raw .#homeConfigurations.mact2.config.home.opencode.activeProviderName`
   — expected output: `github-copilot`
3. `nix eval --raw .#darwinConfigurations.mact2.config.home-manager.users.jcuzmar.home.opencode.activeProviderName`
   — expected output: `github-copilot` (regression guard — must not regress)
4. Spot-check that other hosts are unaffected:
   - `nix eval --raw .#homeConfigurations.rog.config.home.opencode.activeProviderName`
     — expected: `opencode-go-medium`

### Post-deploy verification (optional but recommended)

After `darwin-rebuild switch --flake .#mact2` or `home-manager switch --flake .#mact2` on mact2:

```bash
ssh mact2.local "grep -o '\"github-copilot[^\"]*\"' ~/.config/opencode/opencode.json | head -3"
```

Expected: lines showing `github-copilot/...` model assignments.

---

## Migration

No migration is required. The fix is purely in the flake evaluation layer. The next deploy from
either path will write the correct `opencode.json`. There is no state to migrate.

**Recovery path before this fix is deployed** (if needed immediately):

```bash
ssh mact2.local "darwin-rebuild switch --flake ~/.config/nix#mact2"
```

This uses the already-correct nix-darwin path and writes the correct `opencode.json`.

---

## Open Questions

| # | Question | Status | Suggested resolution |
|---|----------|--------|----------------------|
| Q1 | Should a comment be added to `darwin/default.nix` noting that `flake.nix` must be kept in sync? | Open | Recommended — a one-line comment on line 56 referencing `flake.nix:mact2` prevents future drift |
| Q2 | Should a CI eval check be added to enforce that both targets resolve identically? | Deferred | Desirable but out of scope per the spec; a future `checks` entry could enforce this |
| Q3 | Could `mkDarwinHost` be refactored to also produce a standalone HM target that shares the same override logic? | Out of scope | Would reduce duplication but requires significant refactor; not warranted for a 1-line fix |

---

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Changed files | 1 (`flake.nix`) |
| Estimated changed lines | ~4 (1 inline module line + 3 comment lines) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Decision needed before apply | No |

---

## Relevant Files (for implementer reference)

| File | Role |
|------|------|
| `flake.nix:304-310` | `homeConfigurations.mact2` definition — the only file to edit |
| `darwin/default.nix:48-57` | Nix-darwin HM user block — authoritative override source (unchanged) |
| `shared/opencode.nix:322-330` | `home.opencode.activeProviderName` option definition |
| `shared/opencode/providers-base.nix:3` | Default `activeProviderName = "opencode-go-medium"` (function argument default) |
| `home-darwin/shared-modules.nix` | Canonical Darwin HM module list (unchanged) |
| `lib/mkDarwinHost.nix` | Darwin host builder — does NOT propagate host overrides to standalone HM |

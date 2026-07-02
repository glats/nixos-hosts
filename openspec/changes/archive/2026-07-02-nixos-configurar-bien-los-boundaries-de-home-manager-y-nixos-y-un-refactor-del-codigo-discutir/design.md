# Design: Linux Home Manager Composition Alignment

**Change**: nixos-configurar-bien-los-boundaries-de-home-manager-y-nixos-y-un-refactor-del-codigo-discutir
**Domain**: linux-hm-composition-alignment
**Phase**: design
**Date**: 2026-07-02
**Status**: ready-for-tasks

---

## Quick Path

The change is a single-file edit to `flake.nix`. Two attribute entries in
`homeConfigurations` are replaced, and two comment blocks are updated to remain
truthful after the refactor. No other file changes are needed.

1. Replace `homeConfigurations.rog` with a direct `homeManagerConfiguration`
   call that imports `hosts/rog/home/modules.nix`.
2. Replace `homeConfigurations.thinkcentre` with the same pattern pointing at
   `hosts/thinkcentre/home/modules.nix`.
3. Update the `linuxHomeModules` comment block (lines 152-156) to reflect that
   `linuxHomeModules` no longer drives the Linux standalone path sync; that role
   belongs to the per-host `modules.nix` files after this change.
4. Update the comment preceding the `t14` entry to explicitly mark it as an
   intentional exception to the per-host `modules.nix` ownership model.
5. Verify with `nix flake check --no-build` (repo-level flake evaluation) and
   explicit standalone HM builds for each host.

---

## Technical Approach

### Problem (code-verified)

`flake.nix` lines 239-245 currently read:

```nix
rog = baseHomeConfig "rog" "x86_64-linux" "glats" [
  ./home-linux/conky-rog.nix
  ./home-linux/openfang.nix
];
thinkcentre = baseHomeConfig "thinkcentre" "x86_64-linux" "glats" [
  ./home-linux/conky-thinkcentre.nix
];
```

`baseHomeConfig` calls `mkHomeConfig`, which prepends `linuxHomeModules`
(= `home-linux/shared-modules.nix`) then appends the two extra modules.

The NixOS-integrated path (`modules/base/home-manager.nix` line 23) imports:

```nix
hosts/${config.networking.hostName}/home/modules.nix { inherit inputs; }
```

`hosts/rog/home/modules.nix` (verified at line 6-19) expands to
`shared-modules` plus 7 path entries plus one inline option override:

```nix
baseModules
++ [
  ../../../home-linux/remote-desktop.nix
  ../../../home-linux/picom.nix
  ../../../home-linux/mate-rog-autostart.nix
  ../../../home-linux/conky-rog.nix
  ../../../home-linux/openfang.nix
  ../../../home-linux/webcam-rog.nix
  ../../../home-linux/shell-gpt.nix
  # NOTE: the opencode provider override ({ home.opencode.activeProviderName = "nvidia"; })
  # is present but COMMENTED OUT on line 17. It is NOT active.
  { home.shell-gpt.enable = true; }
]
```

`hosts/thinkcentre/home/modules.nix` (verified at lines 6-15) expands to
`shared-modules` plus 3 path entries:

```nix
baseModules
++ [
  ../../../home-linux/remote-desktop.nix
  ../../../home-linux/picom.nix
  ../../../home-linux/conky-thinkcentre.nix
  ../../../home-linux/shell-gpt.nix
  # NOTE: { home.shell-gpt.enable = true; } is present but COMMENTED OUT.
  # shell-gpt is imported but inactive on thinkcentre.
]
```

The standalone path is missing: `remote-desktop`, `picom`,
`mate-rog-autostart` (rog), `webcam-rog` (rog), `shell-gpt` (both),
and the `{ home.shell-gpt.enable = true; }` inline override (rog).

### Solution

Replace both entries with direct `home-manager.lib.homeManagerConfiguration`
calls that import the per-host `modules.nix` file:

```nix
# After — rog
rog = home-manager.lib.homeManagerConfiguration {
  pkgs = pkgsFor "x86_64-linux";
  modules = import ./hosts/rog/home/modules.nix { inherit inputs; };
  extraSpecialArgs = {
    inherit inputs;
    hostName = "rog";
    username = "glats";
  };
};

# After — thinkcentre
thinkcentre = home-manager.lib.homeManagerConfiguration {
  pkgs = pkgsFor "x86_64-linux";
  modules = import ./hosts/thinkcentre/home/modules.nix { inherit inputs; };
  extraSpecialArgs = {
    inherit inputs;
    hostName = "thinkcentre";
    username = "glats";
  };
};
```

`baseHomeConfig` and `mkHomeConfig` are NOT removed. They remain in `flake.nix`
and continue serving:
- `homeConfigurations.mact2` (Darwin, `x86_64-darwin`)
- any future host that does not yet have a dedicated `modules.nix`

`linuxHomeModules` is NOT removed (see AD-5 for rationale).

---

## Architecture Decisions

### AD-1: Direct call over wrapper function

**Decision**: Use `home-manager.lib.homeManagerConfiguration` directly, not
via `mkHomeConfig`/`baseHomeConfig`.

**Rationale**: `mkHomeConfig` always prepends `linuxHomeModules` and then
appends `extraModules`. The per-host `modules.nix` files already include
`shared-modules.nix` in their composition. Using `mkHomeConfig` would prepend
`shared-modules.nix` a second time, causing duplicate module evaluation. A
direct call with `modules = import ./hosts/.../modules.nix { inherit inputs; }`
is the only correct pattern.

**Alternative rejected**: Modify `mkHomeConfig` to accept a "skip-base" flag.
Adds complexity for a change scoped to two entries.

### AD-2: extraSpecialArgs omit conkyConfig

**Decision**: The standalone `extraSpecialArgs` for `rog` and `thinkcentre`
do NOT include `conkyConfig`.

**Rationale**: Code inspection of `home-linux/conky-rog.nix` (line 167) and
`home-linux/conky-thinkcentre.nix` (line 167) confirms both files define their
own `conkyConfig` as a `let` binding (`pkgs.writeText "conky.conf" ...`).
Neither file consumes `conkyConfig` from the module arguments or from
`extraSpecialArgs`. The `conkyConfig = config.conky-config` passed by
`modules/base/home-manager.nix` (line 16) is a NixOS-sourced value that was
never consumed by these HM modules. Omitting it from standalone is safe.

**Verification**: Neither `conky-rog.nix` nor `conky-thinkcentre.nix` has
a top-level argument named `conkyConfig` in their function signature. Both
open with `{ config, lib, pkgs, ... }:`.

### AD-3: All newly-included modules are standalone-compatible

**Decision**: No module compatibility exceptions are required.

**Evidence** (each module inspected):

| Module | Standalone compatibility verdict |
|--------|-----------------------------------|
| `remote-desktop.nix` | SAFE — pure HM: file writes, `home.packages`, no `osConfig` refs |
| `picom.nix` | SAFE — pure HM `services.picom` option block |
| `mate-rog-autostart.nix` | SAFE — pure `xdg.configFile` write |
| `webcam-rog.nix` | SAFE — pure `home.packages` + `xdg.desktopEntries` |
| `shell-gpt.nix` | SAFE — option-guarded; only activates when `home.shell-gpt.enable = true` (set inline in rog `modules.nix`; commented out in thinkcentre `modules.nix`) |
| `openfang.nix` | SAFE — uses `sops.secrets` (HM sops module works without NixOS integration); sops file paths are relative to the flake root |
| `conky-rog.nix` | SAFE — standalone-compatible; internal `conkyConfig` let-binding (see AD-2) |
| `conky-thinkcentre.nix` | SAFE — same as above |

No `STANDALONE-EXCEPTION:` comment annotations are needed in `modules.nix`
files because all modules are compatible. Spec requirement HM-SA-05 is
satisfied by absence of exceptions.

### AD-4: t14 remains unchanged as a documented special case

**Decision**: `homeConfigurations.t14` is not touched.

**Rationale**: `t14` uses a bespoke `home-manager.lib.homeManagerConfiguration`
call already in `flake.nix` (lines 258-282) with explicit `omarchy.*` inline
config to substitute for the NixOS-integrated `osConfig.omarchy` sync.
This is architecturally sound for a curated Omarchy consumer. The existing
comment block (lines 246-256) explains the reason. A new comment line must be
added to `t14` in the refactored block to explicitly mark it as an intentional
exception to the HM-SA-01 ownership rule, as required by spec HM-SA-04.

### AD-5: baseHomeConfig and linuxHomeModules let-bindings retained

**Decision**: The `let baseHomeConfig = ... in { ... }` wrapper in
`homeConfigurations` and the `linuxHomeModules` let-binding in the outer `let`
block are both kept unchanged.

**Rationale for `baseHomeConfig`**: `mact2` uses `baseHomeConfig` and must not
be disrupted. Removing the wrapper would require inlining `mkHomeConfig` for
`mact2`, which is out of scope and adds churn without benefit.

**Rationale for `linuxHomeModules`**: After this change, `linuxHomeModules` is
defined at `flake.nix` line 157 and is still referenced by `mkHomeConfig`
(line 171) via the `if nixpkgs.lib.hasSuffix "linux" system then linuxHomeModules`
branch. However:

- The only remaining callers of `mkHomeConfig` after this change are
  `baseHomeConfig` calls for `mact2` (system = `x86_64-darwin`).
- `mact2` takes the `else darwinHomeModules` branch in `mkHomeConfig`,
  so `linuxHomeModules` is never selected at runtime after this change.
- `linuxHomeModules` also appears as an import inside each per-host
  `modules.nix` via `shared-modules.nix`, but that is an internal concern of
  those files, not the `flake.nix` variable.
- Removing `linuxHomeModules` from `flake.nix` would require refactoring
  `mkHomeConfig` itself (removing the `hasSuffix` branch or the variable), which
  is out of scope. The let-binding being unused after this change is benign —
  Nix ignores unused let bindings. Removing it is deferred.

---

## Data Flow

### Before (rog standalone)

```
flake.nix homeConfigurations.rog
  -> baseHomeConfig "rog" "x86_64-linux" "glats" [conky-rog, openfang]
     -> mkHomeConfig
        -> linuxHomeModules (shared-modules.nix)
        ++ [conky-rog, openfang]
     -> extraSpecialArgs: { inputs, username, hostName, primaryUser, javaVersion }
```

Missing from integrated path: remote-desktop, picom, mate-rog-autostart,
webcam-rog, shell-gpt, { home.shell-gpt.enable = true; }

### After (rog standalone)

```
flake.nix homeConfigurations.rog
  -> home-manager.lib.homeManagerConfiguration
     modules = import ./hosts/rog/home/modules.nix { inherit inputs; }
       -> shared-modules.nix (base)
       ++ [remote-desktop, picom, mate-rog-autostart, conky-rog, openfang,
           webcam-rog, shell-gpt, { home.shell-gpt.enable = true; }]
       # NOTE: { home.opencode.activeProviderName = "nvidia"; } is commented out
       # in hosts/rog/home/modules.nix line 17 — it is NOT active.
     -> extraSpecialArgs: { inputs, hostName = "rog", username = "glats" }
```

Identical active module set to NixOS-integrated path.

### Before (thinkcentre standalone)

```
flake.nix homeConfigurations.thinkcentre
  -> baseHomeConfig "thinkcentre" "x86_64-linux" "glats" [conky-thinkcentre]
     -> mkHomeConfig
        -> linuxHomeModules (shared-modules.nix)
        ++ [conky-thinkcentre]
     -> extraSpecialArgs: { inputs, username, hostName, primaryUser, javaVersion }
```

Missing from integrated path: remote-desktop, picom, shell-gpt

### After (thinkcentre standalone)

```
flake.nix homeConfigurations.thinkcentre
  -> home-manager.lib.homeManagerConfiguration
     modules = import ./hosts/thinkcentre/home/modules.nix { inherit inputs; }
       -> shared-modules.nix (base)
       ++ [remote-desktop, picom, conky-thinkcentre, shell-gpt]
       # NOTE: { home.shell-gpt.enable = true; } is commented out
       # in hosts/thinkcentre/home/modules.nix line 14 — shell-gpt is imported
       # but inactive (option-guarded by mkIf cfg.enable).
     -> extraSpecialArgs: { inputs, hostName = "thinkcentre", username = "glats" }
```

Identical active module set to NixOS-integrated path.

---

## File Changes

### flake.nix (only file modified)

Three distinct edit locations within `flake.nix`. All are comment or
`homeConfigurations` attribute changes. No module files change.

---

#### Edit 1: linuxHomeModules ownership comment (lines 152-156)

**Why this edit is required**: Proposal scope item 4 requires updating the
comment block near `mkHomeConfig`/`linuxHomeModules` to reflect the new
ownership model. The current comment (lines 153-156) reads:

```nix
# Canonical base list of shared Home Manager modules. See
# `home-linux/shared-modules.nix` for the full list. The
# NixOS-integrated home-manager module (`modules/base/home-manager.nix`)
# imports the same list, so both code paths stay in sync.
```

The phrase "both code paths stay in sync" was accurate when both the standalone
path and the integrated path both consumed `linuxHomeModules` at the `flake.nix`
level. After this change:

- The integrated path (`modules/base/home-manager.nix`) imports
  `hosts/.../home/modules.nix` directly (unchanged).
- The new standalone path for `rog` and `thinkcentre` also imports
  `hosts/.../home/modules.nix` directly.
- `linuxHomeModules` is only consumed by `mkHomeConfig`, which after this
  change is only called by `mact2` (Darwin), where it takes the
  `darwinHomeModules` branch of the `hasSuffix "linux"` conditional.
- The claim that "both Linux code paths stay in sync" via `linuxHomeModules`
  becomes false and misleading.

**Exact diff shape**:

```nix
# BEFORE (lines 152-159):
# --- Home module lists ---
# Canonical base list of shared Home Manager modules. See
# `home-linux/shared-modules.nix` for the full list. The
# NixOS-integrated home-manager module (`modules/base/home-manager.nix`)
# imports the same list, so both code paths stay in sync.
linuxHomeModules = import ./home-linux/shared-modules.nix {
  inherit inputs;
};

# AFTER (same location):
# --- Home module lists ---
# Canonical base list of shared Home Manager modules for Linux. See
# `home-linux/shared-modules.nix` for the full list.
# NOTE: After the Linux HM composition alignment refactor, linuxHomeModules
# is only consumed by mkHomeConfig for the Darwin (mact2) path. The Linux
# standalone paths (rog, thinkcentre) now derive their module lists from
# hosts/<host>/home/modules.nix directly, which itself imports
# shared-modules.nix. The integrated NixOS path (modules/base/home-manager.nix)
# does the same. linuxHomeModules is retained because mkHomeConfig still
# references it for the platform-conditional branch, but it is no longer
# the sync mechanism for Linux standalone HM entries.
linuxHomeModules = import ./home-linux/shared-modules.nix {
  inherit inputs;
};
```

**Estimated delta for this edit**: +6 lines added, -4 lines removed.

---

#### Edit 2: homeConfigurations rog and thinkcentre entries (lines 239-245)

**Location**: Inside the `homeConfigurations` let block.

**Change**: Replace the `rog` and `thinkcentre` `baseHomeConfig` call entries
with direct `homeManagerConfiguration` calls that import the per-host
`modules.nix`.

**Exact diff shape**:

```nix
# REMOVE (lines 239-245):
rog = baseHomeConfig "rog" "x86_64-linux" "glats" [
  ./home-linux/conky-rog.nix
  ./home-linux/openfang.nix
];
thinkcentre = baseHomeConfig "thinkcentre" "x86_64-linux" "glats" [
  ./home-linux/conky-thinkcentre.nix
];

# ADD in place:
# Standalone HM for rog: derives from hosts/rog/home/modules.nix,
# the same source used by the NixOS-integrated path.
rog = home-manager.lib.homeManagerConfiguration {
  pkgs = pkgsFor "x86_64-linux";
  modules = import ./hosts/rog/home/modules.nix { inherit inputs; };
  extraSpecialArgs = {
    inherit inputs;
    hostName = "rog";
    username = "glats";
  };
};
# Standalone HM for thinkcentre: same ownership model as rog.
thinkcentre = home-manager.lib.homeManagerConfiguration {
  pkgs = pkgsFor "x86_64-linux";
  modules = import ./hosts/thinkcentre/home/modules.nix { inherit inputs; };
  extraSpecialArgs = {
    inherit inputs;
    hostName = "thinkcentre";
    username = "glats";
  };
};
```

**Estimated delta for this edit**: +16 lines added, -7 lines removed.

---

#### Edit 3: t14 comment annotation (line 246 area)

**Location**: The comment block before `t14 =` inside `homeConfigurations`
(currently lines 246-256).

**Change**: Add one explicit line marking `t14` as an intentional exception
to the per-host `modules.nix` ownership model, per spec HM-SA-04.

**Exact diff shape**:

```nix
# ADD before the existing t14 comment block:
# t14 is an INTENTIONAL EXCEPTION to the per-host modules.nix ownership model
# (spec HM-SA-04). See rationale below.
# t14 uses NixOS-integrated HM.  The standalone entry is
# required by the `hms` alias ...
```

**Estimated delta for this edit**: +2 lines added, 0 lines removed.

---

#### Combined line delta

| Edit | Added | Removed |
|------|-------|---------|
| Edit 1: linuxHomeModules comment | 6 | 4 |
| Edit 2: rog + thinkcentre entries | 16 | 7 |
| Edit 3: t14 exception annotation | 2 | 0 |
| **Total** | **24** | **11** |

Net delta: approximately +24 additions, -11 deletions = ~35 changed lines.
Well within the 400-line review budget.

**No other files change.**

---

## Interfaces

### hosts/rog/home/modules.nix — calling convention (unchanged)

The file is already a function `{ inputs }: list`. The new standalone call
matches the integrated path call pattern exactly:

```nix
# Integrated path (modules/base/home-manager.nix line 23):
import ../../hosts/${config.networking.hostName}/home/modules.nix { inherit inputs; }

# Standalone path (new):
import ./hosts/rog/home/modules.nix { inherit inputs; }
```

Same argument, same result. No interface changes needed.

### extraSpecialArgs contract

| Arg | Integrated path | Standalone (new) | Notes |
|-----|----------------|-------------------|-------|
| `inputs` | yes | yes | required by shared-modules.nix (sops-nix, omarchy-nix) |
| `hostName` | yes (from `config.networking.hostName`) | yes (literal string) | required by base.nix |
| `username` | yes (hardcoded `"glats"`) | yes (literal `"glats"`) | required by base.nix |
| `conkyConfig` | yes (from `config.conky-config`) | NOT PASSED | safe — neither conky module consumes it (see AD-2) |
| `primaryUser` | yes (via mkHomeConfig) | NOT PASSED | Darwin-only; no Linux module uses it |
| `javaVersion` | yes (via mkHomeConfig) | NOT PASSED | Darwin-only; no Linux module uses it |

`primaryUser` and `javaVersion` are defined in `mkHomeConfig`'s
`extraSpecialArgs` block (lines 176-178 of flake.nix). No Linux HM module
references them. Omitting them from the new Linux-specific calls is correct.

---

## Testing and Verification Strategy

### What `nix flake check --no-build` actually validates

`nix flake check --no-build` evaluates the flake outputs that are registered
in `checks.*`. In this repo, `checks.x86_64-linux` (flake.nix lines 200-204)
contains only the three `nixosConfigurations` toplevel derivations:

```nix
checks.x86_64-linux = {
  rog     = self.nixosConfigurations.rog.config.system.build.toplevel;
  thinkcentre = self.nixosConfigurations.thinkcentre.config.system.build.toplevel;
  t14     = self.nixosConfigurations.t14.config.system.build.toplevel;
};
```

`homeConfigurations.rog` and `homeConfigurations.thinkcentre` are NOT
registered in `checks.*`. Therefore `nix flake check --no-build` does NOT
evaluate them. It only evaluates their NixOS counterparts (which are
unaffected by this change) plus the flake schema itself.

### Step 1: Repo-level flake evaluation (schema + NixOS path regression)

```bash
nix flake check --no-build
```

What this validates:
- Flake schema is well-formed.
- `nixosConfigurations.rog`, `nixosConfigurations.thinkcentre`, and
  `nixosConfigurations.t14` evaluate without error (unchanged NixOS paths).
- The `homeConfigurations` attribute set parses (Nix syntax/parse errors will
  surface here because the whole flake is parsed), but individual HM entries
  are NOT deeply evaluated at this step.

Expected: exit 0.

### Step 2: Standalone rog HM evaluation and build

```bash
nix build .#homeConfigurations.rog.activationPackage
```

This is the primary correctness check for the `rog` standalone HM entry.
It fully evaluates and builds the rog standalone HM closure. Any missing
package, option error, module incompatibility, or missing `extraSpecialArgs`
argument surfaces here.

Expected: build succeeds with a `/nix/store/...` result symlink.

### Step 3: Standalone thinkcentre HM evaluation and build

```bash
nix build .#homeConfigurations.thinkcentre.activationPackage
```

Same as above for thinkcentre.

Expected: build succeeds.

### Step 4: Regression check — NixOS-integrated path untouched

```bash
nix build .#nixosConfigurations.rog.config.system.build.toplevel
nix build .#nixosConfigurations.thinkcentre.config.system.build.toplevel
```

Confirms the NixOS-integrated path is not broken by the flake.nix edit.

Expected: both build successfully (pre-existing behavior preserved).

### Step 5: Regression check — other homeConfigurations untouched

```bash
nix build .#homeConfigurations.t14.activationPackage
nix build .#homeConfigurations.mact2.activationPackage
```

Expected: both build successfully (no unintended regressions).

### Step 6: Format

```bash
format-nix
```

Expected: `git diff --stat` shows only `flake.nix` formatted.

### Verification summary

| Step | Command | What it proves |
|------|---------|----------------|
| 1 | `nix flake check --no-build` | Flake schema valid; NixOS paths unbroken |
| 2 | `nix build .#homeConfigurations.rog.activationPackage` | rog standalone HM is correct and complete |
| 3 | `nix build .#homeConfigurations.thinkcentre.activationPackage` | thinkcentre standalone HM is correct and complete |
| 4 | `nix build .#nixosConfigurations.{rog,thinkcentre}.config.system.build.toplevel` | NixOS paths unchanged |
| 5 | `nix build .#homeConfigurations.{t14,mact2}.activationPackage` | Other HM entries unaffected |
| 6 | `format-nix` | Code style clean |

### Scope of validation

No live switch is required by this spec. The change modifies `flake.nix` only
and has no observable effect on running NixOS systems (the NixOS-integrated HM
path is unchanged). Standalone activation testing on a live host is optional
and out of scope for this PR.

---

## Migration Notes

There is no migration burden. The NixOS-integrated path is untouched. Users
running `nixos-rebuild switch` see no change. Users running
`home-manager switch --flake .#rog` or `.#thinkcentre` will get a complete
environment for the first time (previously they were silently missing modules).
This may trigger a home-manager activation that installs previously-absent
packages and dotfiles. This is the correct and intended behavior.

---

## Open Questions

All pre-conditions from the proposal have been resolved by code inspection:

| Question | Resolution |
|----------|-----------|
| Does `conky-rog.nix` guard against missing `conkyConfig` in extraSpecialArgs? | Resolved: both conky modules define their own `conkyConfig` let-binding; they do not consume `extraSpecialArgs.conkyConfig` at all. No guard needed. |
| Are `remote-desktop`, `picom`, `webcam-rog`, `shell-gpt` standalone-safe? | Resolved: all confirmed standalone-safe by direct code inspection. No `osConfig` references. |
| Will `shell-gpt` silently activate on thinkcentre? | Resolved: `{ home.shell-gpt.enable = true; }` is commented out in `hosts/thinkcentre/home/modules.nix` line 14. The module is imported but inactive. |
| Does `openfang.nix` require NixOS wiring? | Resolved: uses only HM sops module (included in shared-modules via `inputs.sops-nix.homeManagerModules.sops`). No NixOS-level secret declarations needed for HM sops. |
| Is `home.opencode.activeProviderName` override active in rog? | Resolved: the override is COMMENTED OUT in `hosts/rog/home/modules.nix` line 17. It is not active in either the standalone or integrated path. |

No open questions remain. This design is implementation-ready.

---

## Delivery Forecast

| Metric | Value |
|--------|-------|
| Files changed | 1 (`flake.nix`) |
| Estimated line delta | ~24 additions, ~11 deletions (~35 changed lines) |
| Review budget risk | Low (well under 400 lines) |
| Chained PRs recommended | No |
| Decision needed before apply | No |

Single PR is appropriate. The change is self-contained and verifiable in one
commit. Three edit locations within `flake.nix`: the `linuxHomeModules` comment
block (lines 152-156), the `rog`/`thinkcentre` entries (lines 239-245), and the
`t14` exception annotation (line 246 area).

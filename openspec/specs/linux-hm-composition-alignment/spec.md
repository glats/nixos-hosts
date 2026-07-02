# Delta Spec: Linux Home Manager Composition Alignment

**Change**: nixos configurar bien los boundaries de home-manager y nixos y un refactor del codigo. discutir
**Domain**: linux-hm-composition-alignment
**Phase**: spec
**Date**: 2026-07-02
**Status**: draft

---

## Summary

This delta spec covers the bounded change that aligns standalone Linux Home Manager
composition (`homeConfigurations.rog` and `homeConfigurations.thinkcentre` in `flake.nix`)
with the NixOS-integrated Linux HM composition path, so both paths derive from the same
per-host ownership source: `hosts/<host>/home/modules.nix`.

It is a correctness fix for a silent environment divergence. Running
`home-manager switch --flake .#rog` currently produces a materially different user
environment than `nixos-rebuild switch` on the same host.

**In scope**: `rog`, `thinkcentre` standalone HM paths only.
**Out of scope**: `t14` (intentional special case — see exception below), `mact2`, NixOS modules.

---

## ADDED Requirements

### Requirement: HM-SA-01 — Per-host modules.nix as the single ownership source

`hosts/<host>/home/modules.nix` MUST be the single authoritative source of the
HM module list for any Linux host, for both the NixOS-integrated path and the
standalone path.

The standalone `homeConfigurations.<host>` entries in `flake.nix` for `rog` and
`thinkcentre` MUST derive their module lists exclusively by importing the
corresponding `hosts/<host>/home/modules.nix` file, rather than constructing an
ad-hoc list from `linuxHomeModules` plus host-specific extras.

The NixOS-integrated path (`modules/base/home-manager.nix`) already satisfies
this requirement by importing `hosts/${config.networking.hostName}/home/modules.nix`
directly and MUST NOT be changed.

#### Scenario: rog standalone imports via modules.nix

- GIVEN the change is applied to `flake.nix`
- WHEN `homeConfigurations.rog` in `flake.nix` is read
- THEN it calls `home-manager.lib.homeManagerConfiguration` with
  `modules = import ./hosts/rog/home/modules.nix { inherit inputs; }`
- AND it does NOT contain any inline `linuxHomeModules ++` appending pattern

#### Scenario: thinkcentre standalone imports via modules.nix

- GIVEN the change is applied to `flake.nix`
- WHEN `homeConfigurations.thinkcentre` in `flake.nix` is read
- THEN it calls `home-manager.lib.homeManagerConfiguration` with
  `modules = import ./hosts/thinkcentre/home/modules.nix { inherit inputs; }`
- AND it does NOT contain any inline `linuxHomeModules ++` appending pattern

#### Scenario: Integrated path is unchanged

- GIVEN the change is applied
- WHEN `modules/base/home-manager.nix` is read
- THEN it still imports `../../hosts/${config.networking.hostName}/home/modules.nix`
- AND no line in that file has been modified

---

### Requirement: HM-SA-02 — Standalone and integrated module lists are provably equivalent

After this change, for `rog` and `thinkcentre`, the set of HM modules evaluated
by `home-manager switch --flake .#<host>` MUST be identical to the set evaluated
by `nixos-rebuild switch`, with the only permitted exceptions being modules that
explicitly require NixOS context (`osConfig`) and are listed in a documented
exception registry (see HM-SA-05).

#### Scenario: rog standalone module set matches integrated module set

- GIVEN `hosts/rog/home/modules.nix` is the shared source
- WHEN `homeConfigurations.rog` and `nixosConfigurations.rog` are both evaluated
- THEN the resolved module list for `homeConfigurations.rog` includes every module
  that `nixosConfigurations.rog` evaluates through its HM path:
  `shared-modules` + `remote-desktop.nix` + `picom.nix` + `mate-rog-autostart.nix`
  + `conky-rog.nix` + `openfang.nix` + `webcam-rog.nix` + `shell-gpt.nix`
  + `{ home.shell-gpt.enable = true; }`
- AND no module present in the integrated path is absent from the standalone path
  (unless documented in the exception registry per HM-SA-05)

#### Scenario: thinkcentre standalone module set matches integrated module set

- GIVEN `hosts/thinkcentre/home/modules.nix` is the shared source
- WHEN `homeConfigurations.thinkcentre` and `nixosConfigurations.thinkcentre` are both evaluated
- THEN the resolved module list for `homeConfigurations.thinkcentre` includes every module
  that `nixosConfigurations.thinkcentre` evaluates through its HM path:
  `shared-modules` + `remote-desktop.nix` + `picom.nix` + `conky-thinkcentre.nix`
  + `shell-gpt.nix`
- AND no module present in the integrated path is absent from the standalone path
  (unless documented in the exception registry per HM-SA-05)

#### Scenario: Previously missing modules are now present in rog standalone

- GIVEN the old `flake.nix` standalone path only appended `conky-rog.nix` and `openfang.nix`
- WHEN the change is applied and `nix build .#homeConfigurations.rog.activationPackage`
  is run
- THEN the build includes `remmina`, `libsecret`, and Remmina profiles (from `remote-desktop.nix`)
- AND `services.picom.enable` is set to `true` (from `picom.nix`)
- AND `home.packages` includes the `webcam` script (from `webcam-rog.nix`)
- AND `home.packages` includes `shell-gpt` (from `shell-gpt.nix` + enable override)

#### Scenario: Previously missing modules are now present in thinkcentre standalone

- GIVEN the old `flake.nix` standalone path only appended `conky-thinkcentre.nix`
- WHEN the change is applied and
  `nix build .#homeConfigurations.thinkcentre.activationPackage` is run
- THEN the build includes `remmina`, `libsecret`, and Remmina profiles (from `remote-desktop.nix`)
- AND `services.picom.enable` is set to `true` (from `picom.nix`)

---

### Requirement: HM-SA-03 — Standalone composition passes extraSpecialArgs sufficient for all imported modules

The `extraSpecialArgs` supplied to `home-manager.lib.homeManagerConfiguration` for
`rog` and `thinkcentre` MUST include every argument required by any module reachable
through `hosts/<host>/home/modules.nix`.

The following args are required by the current module graph and MUST be present:

| Argument   | Required by                          | Notes                                       |
|------------|--------------------------------------|---------------------------------------------|
| `inputs`   | `shared-modules.nix`, `sops-nix` HM | Already supplied by `mkHomeConfig`          |
| `hostName` | `home-linux/base.nix`, `ssh.nix`     | Must match the host string (e.g. `"rog"`)  |
| `username` | `home-linux/base.nix`                | Must be `"glats"` for Linux hosts          |

The `conkyConfig` arg supplied by the integrated path (`modules/base/home-manager.nix`
line 16: `conkyConfig = config.conky-config`) MUST NOT be required by standalone
composition. The `conky-rog.nix` and `conky-thinkcentre.nix` modules define their own
internal `conkyConfig` local variable and do NOT consume any arg named `conkyConfig`
from `extraSpecialArgs`. This has been verified in the source code.

#### Scenario: Standalone rog build does not fail due to missing conkyConfig

- GIVEN `conkyConfig` is NOT present in `extraSpecialArgs` for `homeConfigurations.rog`
- WHEN `nix build .#homeConfigurations.rog.activationPackage` is evaluated
- THEN the build succeeds with exit code 0
- AND no evaluation error mentioning `conkyConfig` or `config.conky-config` is emitted

#### Scenario: Standalone thinkcentre build does not fail due to missing conkyConfig

- GIVEN `conkyConfig` is NOT present in `extraSpecialArgs` for `homeConfigurations.thinkcentre`
- WHEN `nix build .#homeConfigurations.thinkcentre.activationPackage` is evaluated
- THEN the build succeeds with exit code 0
- AND no evaluation error mentioning `conkyConfig` or `config.conky-config` is emitted

#### Scenario: inputs arg is available to all modules

- GIVEN the standalone `homeConfigurations.rog` entry passes `extraSpecialArgs = { inherit inputs; hostName = "rog"; username = "glats"; }`
- WHEN `home-linux/shared-modules.nix` is evaluated (which imports `inputs.sops-nix.homeManagerModules.sops`)
- THEN the sops HM module resolves without error

---

### Requirement: HM-SA-04 — t14 standalone path is an intentional, documented special case

The `homeConfigurations.t14` entry in `flake.nix` SHALL remain unchanged. It uses
`home-manager.lib.homeManagerConfiguration` directly with `hosts/t14/home/omarchy.nix`
and explicit `omarchy.*` attribute injection. This differs structurally from the
`rog` / `thinkcentre` pattern for valid reasons:

- `t14` is an Omarchy consumer, not a plain HM host.
- `t14` has no `hosts/t14/home/modules.nix` file; its standalone HM is defined
  via `hosts/t14/home/omarchy.nix`.
- The Omarchy NixOS module copies `osConfig.omarchy` into HM context; in standalone
  mode, `osConfig = {}` so those values must be injected explicitly.
- Applying `linuxHomeModules` (which includes non-Omarchy MATE, Picom, etc.) to
  `t14` would cause module conflicts with the Omarchy desktop stack.

The existing `flake.nix` comment block documenting the t14 special case MUST be
preserved and SHOULD be updated to explicitly name this as an "intentional special
case" excluded from the HM-SA-01 ownership rule.

#### Scenario: t14 homeConfiguration is not modified

- GIVEN the change is applied to `flake.nix`
- WHEN `homeConfigurations.t14` is read
- THEN its structure is identical to the pre-change version
- AND it still uses `./hosts/t14/home/omarchy.nix` as its module entry
- AND the `omarchy.*` attribute injection block is still present

#### Scenario: t14 comment documents the special case

- GIVEN the change is applied
- WHEN the comment block preceding `homeConfigurations.t14` in `flake.nix` is read
- THEN it contains an explicit statement marking `t14` as an intentional exception
  to the per-host `modules.nix` ownership model

---

### Requirement: HM-SA-05 — Module compatibility exception registry

If any module reachable through `hosts/<host>/home/modules.nix` is excluded from the
standalone composition because it requires NixOS context unavailable in standalone
HM, that exclusion MUST be documented as a named exception in one of:

1. An inline comment in the relevant `hosts/<host>/home/modules.nix` file, OR
2. A dedicated `exception` key in the host's `modules.nix` file (using a `# STANDALONE-EXCEPTION:` comment marker).

The exception documentation MUST state:
- Which module is excluded or limited.
- What NixOS context it requires.
- What the standalone fallback behavior is (e.g. "module still imported; option
  has no effect without osConfig").

As of this change, the following modules are verified to work in standalone mode
WITHOUT requiring any exception:

| Module                   | Dependency check result                                   |
|--------------------------|-----------------------------------------------------------|
| `remote-desktop.nix`     | No `osConfig` refs; uses only `lib`, `pkgs`, `...`       |
| `picom.nix`              | No `osConfig` refs; uses `...` only                      |
| `mate-rog-autostart.nix` | No `osConfig` refs; uses `pkgs`, `...` only              |
| `conky-rog.nix`          | No `osConfig` refs; uses `config`, `lib`, `pkgs`, `...`  |
| `conky-thinkcentre.nix`  | No `osConfig` refs; uses `config`, `lib`, `pkgs`, `...`  |
| `openfang.nix`           | No `osConfig` refs; uses HM `sops.secrets` and user-level files/services only |
| `webcam-rog.nix`         | No `osConfig` refs; uses `lib`, `pkgs`, `...`            |
| `shell-gpt.nix`          | No `osConfig` refs; uses standard HM option surface       |

#### Scenario: Exception registry is empty for this change

- GIVEN the change is applied
- WHEN `hosts/rog/home/modules.nix` and `hosts/thinkcentre/home/modules.nix` are read
- THEN neither file contains a `# STANDALONE-EXCEPTION:` marker
- (This is the expected state — all modules in scope are standalone-compatible)

#### Scenario: Future module with osConfig dependency gets a registry entry

- GIVEN a developer adds a new module to `hosts/rog/home/modules.nix` that references `osConfig`
- WHEN the PR is reviewed
- THEN the module file MUST contain either an internal guard (`osConfig ? someAttr -> mkIf`)
  OR a `# STANDALONE-EXCEPTION:` comment in `hosts/rog/home/modules.nix` explaining the limitation

---

### Requirement: HM-SA-06 — Repo-level flake evaluation and explicit standalone HM builds pass after the change

After the change, `nix flake check --no-build` MUST pass with exit code 0 for the
entire flake. In this repo, that validates the flake schema and the registered
`checks.x86_64-linux` outputs, which point at the NixOS system toplevels for
`rog`, `thinkcentre`, and `t14`.

Standalone Home Manager entries are NOT part of `checks.x86_64-linux` and MUST
be validated explicitly with `nix build .#homeConfigurations.<host>.activationPackage`.

Therefore, this requirement proves two things separately:
- repo-level flake evaluation remains valid (`nix flake check --no-build`)
- standalone HM evaluation for `rog` and `thinkcentre` remains valid (explicit builds)

#### Scenario: Full flake check passes

- GIVEN the change is applied to `flake.nix`
- WHEN `nix flake check --no-build` is run from the repo root
- THEN exit code is 0
- AND no evaluation errors are printed for the registered flake outputs or
  `checks.x86_64-linux` entries

#### Scenario: Standalone rog build succeeds

- GIVEN the change is applied
- WHEN `nix build .#homeConfigurations.rog.activationPackage` is run
- THEN exit code is 0
- AND the result symlink points to a valid activation package derivation

#### Scenario: Standalone thinkcentre build succeeds

- GIVEN the change is applied
- WHEN `nix build .#homeConfigurations.thinkcentre.activationPackage` is run
- THEN exit code is 0
- AND the result symlink points to a valid activation package derivation

#### Scenario: NixOS build for rog is unaffected

- GIVEN the change is applied
- WHEN `nix build .#nixosConfigurations.rog.config.system.build.toplevel` is run
- THEN exit code is 0 (same as pre-change)

---

## Context: Why conkyConfig is not a blocking dependency

The proposal identified `conkyConfig = config.conky-config` (passed by
`modules/base/home-manager.nix`) as a potential risk for standalone composition.

Code review confirms this risk does NOT materialize:

- `home-linux/conky-rog.nix` and `home-linux/conky-thinkcentre.nix` each define a
  local variable named `conkyConfig` (a `pkgs.writeText` derivation) entirely
  within the `let` block of the module.
- Neither module has a function parameter named `conkyConfig`; their parameter
  lists are `{ config, lib, pkgs, ... }`.
- The `conkyConfig` arg in `extraSpecialArgs` from the integrated path is never
  consumed by any module in scope. It is a dead arg from the HM module boundary
  perspective (it may be consumed by a different NixOS module in the integrated
  path, but that is outside the HM boundary).

This means the standalone path can provide `extraSpecialArgs = { inherit inputs; hostName = ...; username = ...; }` without supplying `conkyConfig` and all conky modules will evaluate correctly.

---

## Out-of-scope clarifications

| Topic | Status |
|-------|--------|
| `t14` Omarchy `mkForce` cleanup | Deferred — separate proposal required |
| `home-linux/ghostty.nix`, `kitty.nix`, `git.nix` shim cleanup | Deferred |
| NixOS/HM boundary contract documentation | Deferred |
| Font/theme layer ownership documentation | Deferred |
| `linuxHomeModules` variable removal from `flake.nix` | Deferred — after this change it becomes an unused let-binding in `flake.nix`, but cleanup is intentionally outside this slice |
| `mact2` Darwin standalone path | Unaffected, no change |

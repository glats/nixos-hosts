# Exploration Report: Refactor mact2 Darwin

**Date**: 2026-07-06
**Status**: Complete
**SDD Phase**: Explore (re-exploration)

---

## 1. Current State: Darwin vs NixOS Patterns

### 1.1 NixOS Module Hierarchy (THE pattern to mirror)

The NixOS side uses a clean three-tier profile chain with categorized subdirectories:

```
modules/
  profiles/
    base.nix       -- imports from ../base/*, ../networking/*, ../features/*
    desktop.nix    -- imports ./base.nix + ../desktop/* + ../hardware/*
    server.nix     -- imports ./desktop.nix + ../features/services/* + ../networking/* + ../virtualisation/*
  base/            -- Atomic modules: nix.nix, users.nix, cachix.nix, sops.nix, zsh.nix, etc.
  desktop/         -- font.nix, i18n.nix, kmscon.nix
  features/        -- boot.nix, conky/, services/
  hardware/        -- nvidia.nix, amd-laptop.nix, keyring.nix
  networking/      -- openssh.nix, firewall.nix, avahi.nix, wol.nix
  virtualisation/  -- docker.nix, libvirt.nix
```

**Key characteristics of this pattern:**
- Each profile file is a pure import aggregator (no inline config)
- Profiles chain: server imports desktop imports base
- Subdirectories are cleanly organized by concern (base, desktop, hardware, networking, features, virtualisation)
- Hosts import the profile they need (e.g., rog imports server.nix)
- Per-host configs live in `hosts/<name>/default.nix` and `hosts/<name>/home/modules.nix`

### 1.2 Darwin Module Structure (CURRENT - flat and monolithic)

```
darwin/
  default.nix      -- 93 lines: aggregator + nix config + home-manager config + user config + environment
  settings.nix     -- 230 lines: macOS preferences + firewall + SSH + activation scripts
  homebrew.nix     -- 64 lines: pure homebrew configuration
  cachix.nix       -- 107 lines: nix settings (substituters, build opts, registry)
  mise.nix         -- 84 lines: activation scripts for mise tooling
  wsdd.nix         -- 86 lines: full service module with options/config pattern
```

**Problems with this structure:**

1. **Flat directory** -- All 6 files sit at the same level with zero subdirectories. No categorization by concern.

2. **`default.nix` is overloaded** -- It acts as both an import aggregator AND contains inline configuration (nix.settings, nix-homebrew, home-manager config, environment variables, system packages, user config, services.wsdd enablement). The NixOS profiles are pure import aggregators only.

3. **No profile chain** -- There is no equivalent of `base.nix -> desktop.nix -> server.nix`. There's nothing to import into for a hypothetical second Darwin host.

4. **`hosts/mact2/default.nix` is hollow** -- 16 lines, only sets `networking.hostName = host`. All real config bypasses the host file and lives in `darwin/default.nix`. This means the host can't override or extend Darwin behavior cleanly.

5. **`mkDarwinHost.nix` imports `../darwin` as a flat directory** -- Every Darwin host gets ALL darwin modules regardless of whether they're applicable.

6. **`darwin/default.nix` duplicates concerns from individual module files** -- nix settings are partially in `cachix.nix` and partially in `default.nix`. User config lives in `default.nix`. Environment config lives in `default.nix`. These should be in their own categorized modules.

### 1.3 Cross-Platform Concerns Already Well-Structured

The following patterns are already well-executed and should be PRESERVED:

```
shared/                       -- Cross-platform HM modules (shell-aliases, opencode, sops)
  opencode.nix
  opencode-profile.nix
  shell-aliases.nix
  sops.nix

home-darwin/shared-modules.nix -- Darwin HM canonical module list
home-linux/shared-modules.nix  -- Linux HM canonical module list
```

These `shared-modules.nix` files are the single-source-of-truth for HM modules, and both `flake.nix` and the respective `default.nix` import from them. This is a GOOD pattern that should be replicated at the system-module level.

---

## 2. Identified Inconsistencies (Verified)

### 2.1 GPG ~90% Duplication

- `home-linux/gpg.nix` (28 lines): gnupg + pinentry-curses
- `home-darwin/gpg.nix` (29 lines): gnupg + pinentry_mac + nix-index

The import logic is identical. Difference: package list (pinentry-curses vs pinentry_mac) and one extra package (nix-index on darwin). The shared import logic should be extracted.

### 2.2 Ghostty Config Divergence

- `home-linux/ghostty.nix` (80 lines): Uses `programs.ghostty` HM module with `lib.mkForce` settings + `themes` attrset with nix-colors palette
- `home-darwin/ghostty.nix` (50 lines): Uses raw `home.file` to write config files manually (no `programs.ghostty` module). Same config values but duplicated as text strings.

The Darwin version predates the `programs.ghostty` module supporting darwin. The palette generation code is duplicated between two different syntaxes.

### 2.3 Redundant Cachix/Substituter Import

`darwin/cachix.nix` duplicates the same substituter list and build optimization settings as `modules/base/cachix.nix` and `modules/base/nix.nix`. The Fastly mirrors, cachix URLs, trusted keys, max-jobs, cores, keep-outputs, and registry pinning are all mirrored with minor platform-specific differences.

### 2.4 `hosts/mact2/default.nix` Hollow

16 lines. Only sets `networking.hostName`. Everything else lives in `darwin/default.nix` (over 93 lines of config that should be delegatable to the host). The host can't choose which darwin modules to import or override.

### 2.5 No Darwin Service Subdirectory

Unlike NixOS hosts where services live in `hosts/<name>/services/`, there is no per-host services directory for mact2. `wsdd.nix` lives in `darwin/` (shared across all Darwin hosts) instead of being host-scoped.

### 2.6 `specialArgs` Asymmetry

`mkDarwinHost.nix` passes `specialArgs` twice (once for darwinSystem and once for home-manager.extraSpecialArgs), while `mkHost.nix` passes only once for nixosSystem. This is partly because `mkDarwinHost.nix` manually passes `home-manager.extraSpecialArgs` inline (instead of letting `darwin/default.nix`'s home-manager config handle it). This creates a specialArgs leak where `darwin/default.nix` also passes `extraSpecialArgs` -- resulting in double-passing.

---

## 3. External Patterns (MCP Research)

### 3.1 Pattern A: Jadarma's Unified Per-Feature with Platform Files

```
modules/
  gpg/
    common.nix      -- shared options/assertions
    darwin.nix      -- macOS-specific system config
    nixos.nix       -- NixOS-specific system config
    home.nix        -- HM config (both platforms, uses osConfig)
```

**Relevant to us**: The `common.nix` pattern for shared options and the per-platform system files. However, Jadarma warns: "the intersection between the two platforms' module systems is too small to be useful" for deep sharing of system modules.

**Takeaway**: This pattern is good for HM modules (where both platforms share ~90% of options) but overkill for system modules where the overlap is minimal. Our `shared/` directory already handles the HM unification case well.

### 3.2 Pattern B: kclejeune's Categorized Platform Dirs

```
modules/
  darwin/           -- Darwin-specific system modules
  nixos/            -- NixOS-specific system modules
  home/             -- Home Manager modules
  shared/           -- Cross-platform modules
  profiles/         -- Profile aggregation
```

**Relevant to us**: This is the closest to our existing NixOS pattern. The idea of having `modules/darwin/` alongside `modules/nixos/` (instead of a top-level `darwin/`) is worth considering.

**Takeaway**: Our existing `modules/` directory could absorb darwin system modules using a `modules/darwin/` subdirectory, keeping the NixOS host support (`modules/base/`, `modules/desktop/`, etc.) untouched.

### 3.3 Pattern C: MatthiasBenaets' Host-Categorized Modules

```
modules/
  hosts/
    darwin/          -- Darwin-specific host config
    nixos/           -- NixOS-specific host config
  general/           -- Shared cross-platform modules
  editors/
  gui/
  services/
```

**Relevant to us**: Host-specific modules grouped by platform. Our existing `hosts/mact2/` already handles per-host config, but the darwin modules themselves are not organized.

### 3.4 Pattern D: Dendritic Pattern (Christopher2K, AlexNabokikh)

```
modules/
  features/
    terminal.nix    -- flake.modules.nixos.terminal + darwin.terminal + homeManager.terminal
```

Uses flake-parts and auto-importing. Heavy infrastructure for a small config like ours.

**Takeaway**: Not suitable for our scale. Too much flake-parts overhead for a single Darwin host.

### 3.5 Common Theme Across All External Patterns

**Every** well-structured config uses CATEGORIZED subdirectories for system modules. No flat directory of files. The specific categories vary, but the principle is universal: group by concern, not by file type.

---

## 4. Good Patterns to Preserve (Verified)

These patterns from the existing codebase should NOT be changed:

1. **`shared-modules.nix` canonical lists** -- Both `home-linux/shared-modules.nix` and `home-darwin/shared-modules.nix` serve as the single source of truth for HM module lists. Both the `flake.nix` bindings and the `default.nix` import from them.

2. **Cross-platform `shared/` directory** -- `shared/opencode.nix`, `shared/shell-aliases.nix`, `shared/opencode-profile.nix` are cleanly separated from platform-specific modules.

3. **`mkDarwinHost` and `mkHost` builders** -- The abstraction of host creation into `lib/` functions is clean. The NixOS version (`mkNixosHost`) is a cleaner model to follow.

4. **Per-host home `modules.nix` pattern** -- `hosts/rog/home/modules.nix` imports `shared-modules.nix` as base and appends host-specific modules. This gives each host ownership of its HM module list.

5. **`wsdd.nix` module pattern** -- The `options` + `config` structure in `darwin/wsdd.nix` is a textbook NixOS module. It declares options with `mkEnableOption`/`mkOption` and uses `mkIf cfg.enable` for the implementation. This should be the template for new darwin modules.

---

## 5. Recommended Refactoring Areas (Top 2-3)

### 5.1 AREA 1: Introduce Darwin Profile Chain (HIGHEST IMPACT)

**Problem**: `darwin/default.nix` is both an aggregator AND contains inline config. There is no profile chain. Adding a second Darwin host is painful.

**Approach**: Create a Darwin equivalent of the NixOS profile chain.

**New structure:**

```
modules/darwin/                    -- NEW: Darwin system modules (alongside modules/base/, modules/desktop/, etc.)
  profiles/
    base.nix                       -- NEW: imports categorized darwin modules (mirrors modules/profiles/base.nix)
  system/
    nix.nix                        -- EXTRACTED from darwin/cachix.nix + darwin/default.nix (nix.settings, registry)
    cachix.nix                     -- MOVED from darwin/cachix.nix (substituters, trusted keys)
    homebrew.nix                   -- MOVED from darwin/homebrew.nix
    settings.nix                   -- MOVED from darwin/settings.nix
    mise.nix                       -- MOVED from darwin/mise.nix
  services/
    wsdd.nix                       -- MOVED from darwin/wsdd.nix

darwin/                            -- SIMPLIFIED: just default.nix (thin aggregator for home-manager + user)
  default.nix                      -- REFACTORED: imports modules/darwin/profiles/base.nix + HM config + user config
```

**What `modules/darwin/profiles/base.nix` would look like:**

```nix
{
  imports = [
    ../system/nix.nix
    ../system/cachix.nix
    ../system/homebrew.nix
    ../system/settings.nix
    ../system/mise.nix
    ../services/wsdd.nix
  ];
}
```

**What the refactored `darwin/default.nix` would look like:**

```nix
{ pkgs, inputs, self, primaryUser, javaVersion, lib, ... }:
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
    ../modules/darwin/profiles/base.nix    -- Single import for all darwin system modules
  ];

  nix-homebrew = {
    user = primaryUser;
    enable = true;
    autoMigrate = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.${primaryUser} = {
      imports = [ ../home-darwin ];
      home.stateVersion = "25.05";
      home.opencode.activeProviderName = "github-copilot";
    };
    extraSpecialArgs = { inherit inputs self primaryUser javaVersion; };
  };

  system.primaryUser = primaryUser;
  users.users.${primaryUser} = {
    home = "/Users/${primaryUser}";
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMigT6lscyISTW6jbk9c34gMYSaRQIq4tUxMvn7vd6K7 t14"
    ];
  };
  environment = {
    variables.DISPLAY = ":0";
    systemPackages = with pkgs; [ git ];
    systemPath = [ (if pkgs.stdenv.isAarch64 then "/opt/homebrew/bin" else "/usr/local/bin") ];
    pathsToLink = [ "/Applications" ];
  };
}
```

**Files changed:**
| File | Action |
|------|--------|
| `modules/darwin/profiles/base.nix` | NEW -- darwin profile aggregator |
| `modules/darwin/system/nix.nix` | NEW -- extracted nix settings from cachix.nix + default.nix |
| `modules/darwin/system/cachix.nix` | MOVED from `darwin/cachix.nix` |
| `modules/darwin/system/homebrew.nix` | MOVED from `darwin/homebrew.nix` |
| `modules/darwin/system/settings.nix` | MOVED from `darwin/settings.nix` |
| `modules/darwin/system/mise.nix` | MOVED from `darwin/mise.nix` |
| `modules/darwin/services/wsdd.nix` | MOVED from `darwin/wsdd.nix` |
| `darwin/default.nix` | REFACTORED -- import base.nix instead of individual files |
| `lib/mkDarwinHost.nix` | UPDATE -- import path from `../darwin` to `../modules/darwin/profiles/base.nix` |
| `flake.nix` | No changes needed (keeps importing `../darwin`) |

**Why this is the highest impact area:**
- Directly mirrors the NixOS profile pattern
- Makes the codebase internally consistent (both platforms follow the same organizational model)
- Enables future Darwin hosts by providing a clean import target
- Separates concerns: profile aggregation, system modules, and user config are now distinct layers
- Can be done incrementally (one module move at a time with verification)

---

### 5.2 AREA 2: Fix `mkDarwinHost.nix` specialArgs Asymmetry

**Problem**: `mkDarwinHost.nix` passes `specialArgs` to darwinSystem AND manually passes `home-manager.extraSpecialArgs` inline. Meanwhile, `darwin/default.nix` also sets `home-manager.extraSpecialArgs`. This creates a confusing double-passing that works but is fragile.

**Current `mkDarwinHost.nix` (lines 13-23 vs 42-52):**
```nix
# First: specialArgs to darwinSystem
specialArgs = {
  inherit inputs self username system;
  host = hostname;
  primaryUser = username;
  javaVersion = "temurin-25.0.1+8.0.LTS";
};

# Then later, inline in modules:
{
  home-manager.extraSpecialArgs = {
    inherit inputs self username;
    primaryUser = username;
    javaVersion = "temurin-25.0.1+8.0.LTS";
  };
}
```

**What `mkNixosHost.nix` does (cleaner):**
```nix
# Only specialArgs to nixosSystem
specialArgs = {
  inherit inputs self username;
};

# HM extraSpecialArgs handled by modules/base/home-manager.nix
{
  home-manager.extraSpecialArgs = {
    inherit inputs username;
  };
}
```

**Approach**: Move the `home-manager.extraSpecialArgs` block out of `mkDarwinHost.nix` and let `darwin/default.nix` own it exclusively. The builder should only set `specialArgs` for the system, not for child subsystems.

**Files changed:**
| File | Action |
|------|--------|
| `lib/mkDarwinHost.nix` | REMOVE `home-manager.extraSpecialArgs` block from modules list |
| `darwin/default.nix` | ALREADY sets `home-manager.extraSpecialArgs` -- ensure it's the only place |

**Why this matters:** Simplifies the builder, eliminates duplication, follows the same pattern as the NixOS builder. The mkDarwinHost function becomes as thin and predictable as mkNixosHost.

---

### 5.3 AREA 3: Consolidate GPG and Ghostty Duplication

**Problem 3a (GPG)**: `home-linux/gpg.nix` and `home-darwin/gpg.nix` are ~90% identical. The `importKey` function and activation script are byte-identical. Only the package list differs.

**Approach 3a**: Extract the shared GPG import logic into `shared/gpg.nix` as a function or module that takes the pinentry package as a parameter. Keep per-platform files thin:
- `shared/gpg.nix`: The `importKey` function + activation script
- `home-linux/gpg.nix`: Imports shared GPG, adds `pinentry-curses`
- `home-darwin/gpg.nix`: Imports shared GPG, adds `pinentry_mac`, `nix-index`

**Files changed:**
| File | Action |
|------|--------|
| `shared/gpg.nix` | NEW -- shared GPG import logic |
| `home-linux/gpg.nix` | REFACTORED -- imports shared, only adds linux-specific packages |
| `home-darwin/gpg.nix` | REFACTORED -- imports shared, only adds darwin-specific packages |

**Problem 3b (Ghostty)**: Darwin uses raw `home.file` text while Linux uses `programs.ghostty` HM module. The `programs.ghostty` module supports darwin (since ghostty 1.0+), so the Darwin config can be migrated.

**Approach 3b**: Migrate `home-darwin/ghostty.nix` to use `programs.ghostty` (same as Linux), extract the shared palette/theme generation into a reusable helper, and keep per-platform differences (like `macos-option-as-alt`) as overrides.

**Files changed:**
| File | Action |
|------|--------|
| `home-darwin/ghostty.nix` | REFACTORED -- use `programs.ghostty` instead of `home.file` |
| `shared/ghostty-palette.nix` | NEW (optional) -- shared palette generation helper |

**Why these matter**: Eliminates maintenance drift between platforms. When the GPG activation script or Ghostty theme changes, it only needs to be changed in one place.

---

## 6. What NOT to Refactor (Anti-Recommendations)

### 6.1 Do NOT adopt the Dendritic pattern (flake-parts + import-tree)

**Why**: Too much infrastructure for 1 Darwin host. The flake-parts overhead (new flake input, module registration, namespace management) adds complexity without proportional benefit. Our existing `profiles/` pattern already provides clean aggregation.

### 6.2 Do NOT unify NixOS and Darwin system modules into a single `common.nix`

**Why**: As Jadarma's blog post confirms: "the intersection between the two platforms' module systems is too small to be useful." NixOS options like `boot.*`, `services.xserver.*`, `systemd.*` have no Darwin equivalents. Forcing a `common.nix` abstraction would create awkward `mkIf` guards everywhere.

### 6.3 Do NOT move `darwin/default.nix` entirely into `modules/darwin/`

**Why**: The `darwin/default.nix` currently handles user config, HM setup, and environment variables -- these are per-host concerns. They belong in `darwin/default.nix` or `hosts/mact2/default.nix`, not in shared modules. The refactored `darwin/default.nix` should remain thin but still hold user-level config.

### 6.4 Do NOT change the `shared/` or `shared-modules.nix` structures

**Why**: These are already well-structured cross-platform patterns. The `home-darwin/shared-modules.nix` and `home-linux/shared-modules.nix` canonical list pattern is correct and should be replicated, not reorganized.

---

## 7. Implementation Sequence Recommendation

All three areas can be implemented incrementally. Recommended order:

```
Phase 1: Area 2 (specialArgs fix)           -- 1-2 files, lowest risk, fast verification
Phase 2: Area 1 (Darwin profile chain)       -- 8+ files, core structural change, highest impact
Phase 3: Area 3 (GPG + Ghostty dedup)        -- 3-4 files, cosmetic but reduces maintenance
```

Each phase is independently verifiable with `nix flake check --no-build darwinConfigurations.mact2`.

---

## 8. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Import path breakage during file moves | Medium | High (build fails) | Move files one at a time, verify `nix flake check` after each move |
| `home-manager.extraSpecialArgs` double-passing removed incorrectly | Low | High (HM can't resolve inputs) | Test `darwin-rebuild switch --dry-run` before actual switch |
| `programs.ghostty` darwin support incomplete | Medium | Medium (missing macos-option-as-alt) | Verify ghostty HM module supports darwin since v1.0; fall back to home.file if not |
| GPG shared module breaks activation order | Low | Medium (keys not imported) | Test GPG import on both platforms after refactor |

---

## 9. Key Learnings

- The NixOS pattern (profile chain, categorized modules, per-host ownership) is the gold standard this repo already has. The Darwin side should mirror it, not invent a new pattern.
- `shared-modules.nix` canonical lists are the best pattern in the codebase -- this concept should be extended to system modules too.
- The `wsdd.nix` module structure (`options` + `config` + `mkIf cfg.enable`) is the correct template for any new darwin system modules.
- External configs universally use categorized subdirectories for system modules. Zero flat directories found in any well-maintained config.
- The Dendritic pattern is popular in the community but introduces flake-parts dependency that's unnecessary for a single Darwin host.
- Jadarma's warning about "too small intersection" between NixOS and Darwin system options confirms that system modules should stay platform-separated. Only HM modules benefit from unification.

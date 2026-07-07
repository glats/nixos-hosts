# Design: Refactor mact2 Darwin Configuration

## Architecture Overview

The Darwin configuration currently lives in a flat `darwin/` directory where `default.nix` serves double duty as both an import aggregator and a container for inline configuration (nix settings, homebrew manager, home-manager setup, user config, environment variables). This refactor introduces a three-tier architecture that mirrors the already-proven NixOS profile chain in `modules/profiles/`.

The new structure creates `modules/darwin/` as a first-class peer to `modules/base/`, `modules/desktop/`, etc. Under it, `modules/darwin/profiles/base.nix` serves as a pure import aggregator (identical in function to `modules/profiles/base.nix`). Individual system modules are categorized by concern into `modules/darwin/system/` (nix config, cachix substituters, homebrew, macOS settings, mise tooling) and `modules/darwin/services/` (wsdd daemon). The refactored `darwin/default.nix` becomes a thin per-host layer that imports the profile for system modules and retains only host-specific concerns: nix-homebrew configuration, home-manager setup, user accounts, environment variables, and service enablements.

Additionally, the builder (`lib/mkDarwinHost.nix`) is trimmed to remove a redundant `home-manager.extraSpecialArgs` block, leaving `darwin/default.nix` as the single source of truth for that config. Two Home Manager duplication issues (GPG key import logic and Ghostty terminal config) are also consolidated: shared GPG activation logic into `shared/gpg.nix` and the Darwin Ghostty config migrated from raw `home.file` to the `programs.ghostty` HM module already used on Linux.

## Module Map

### Before (current)

```
darwin/                          -- flat, 6 files, no subdirectories
  default.nix                    -- overloaded: aggregator + nix config + HM config + user config + env
  cachix.nix                     -- substituters + build opts + registry (107 lines)
  homebrew.nix                   -- brew taps, brews, casks (64 lines)
  settings.nix                   -- macOS preferences + firewall + SSH + activation scripts (230 lines)
  mise.nix                       -- mise tooling activation scripts (84 lines)
  wsdd.nix                       -- service module with options/config pattern (86 lines)

modules/                         -- NixOS side (already well-structured)
  profiles/
    base.nix                     -- pure import aggregator for NixOS system modules
    desktop.nix
    server.nix
  base/                          -- NixOS system modules (nix.nix, cachix.nix, users.nix, etc.)
  desktop/
  features/
  hardware/
  networking/
  virtualisation/

lib/
  mkDarwinHost.nix               -- passes specialArgs + redundant HM extraSpecialArgs inline
  mkHost.nix                     -- NixOS builder (cleaner pattern, but also has inline HM extraSpecialArgs)
```

### After (target)

```
modules/darwin/                  -- NEW: first-class peer to modules/base/, modules/desktop/, etc.
  profiles/
    base.nix                     -- NEW: pure import aggregator (mirrors modules/profiles/base.nix)
  system/
    nix.nix                      -- NEW: consolidated nix settings from darwin/default.nix + darwin/cachix.nix
    cachix.nix                   -- MOVED: substituters + trusted-keys only (build opts extracted to nix.nix)
    homebrew.nix                 -- MOVED: content unchanged
    settings.nix                 -- MOVED: content unchanged
    mise.nix                     -- MOVED: content unchanged
  services/
    wsdd.nix                     -- MOVED: content unchanged

darwin/                          -- SIMPLIFIED: only default.nix remains
  default.nix                    -- REFACTORED: imports modules/darwin/profiles/base.nix; inline nix config removed

shared/
  gpg.nix                        -- NEW: shared importKey function + activation script

lib/
  mkDarwinHost.nix               -- TRIMMED: home-manager.extraSpecialArgs block removed

# Unchanged (existing NixOS pattern preserved)
modules/profiles/base.nix        -- NO CHANGE
modules/base/nix.nix             -- NO CHANGE
modules/base/cachix.nix          -- NO CHANGE
hosts/mact2/default.nix          -- NO CHANGE (16 lines, sets networking.hostName)
lib/mkHost.nix                   -- NO CHANGE (still has its own inline HM extraSpecialArgs; separate concern)
flake.nix                        -- NO CHANGE (keeps same import paths and builder calls)
```

## Component Design

### 1. `modules/darwin/profiles/base.nix` (NEW)

**Purpose**: Pure import aggregator for all Darwin system modules. Mirrors `modules/profiles/base.nix` exactly in structure: imports-only, zero inline configuration. This is the single touchpoint that `darwin/default.nix` imports for system-level darwin configuration.

**Rationale**: The NixOS profile chain (`base.nix -> desktop.nix -> server.nix`) is the pattern that makes this repo internally consistent. Darwin should follow the same model. A pure aggregator enables: (a) clean separation between \what Darwin modules exist\` and \`which ones a host imports\`, (b) trivial addition of future Darwin hosts importing the same base profile, and (c) one-line import in `darwin/default.nix` replacing five individual module imports.

**Complete content**:

```nix
# Profile: Darwin base system configuration.
# Pure import aggregator — mirrors modules/profiles/base.nix.
# Contains ONLY an imports list with zero inline configuration.
# Consumed by darwin/default.nix.
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

**Key design constraint**: This file SHALL contain ONLY `{ imports = [ ... ]; }`. No `nix.*`, no `homebrew.*`, no `services.*`, no `environment.*`. This constraint is verified by R1.1 in the spec.

---

### 2. `modules/darwin/system/nix.nix` (NEW)

**Purpose**: Consolidated nix configuration. Extracts inline `nix.*` settings from `darwin/default.nix` (lines 21-33) and build optimization/registry settings from `darwin/cachix.nix` (lines 24-106) into a single module. After extraction, `modules/darwin/system/cachix.nix` contains ONLY substituters and trusted keys.

**Sources extracted from**:
- `darwin/default.nix` lines 20-33: `nix.settings.experimental-features`, `nix.enable = false`, `nixpkgs.config.allowUnfree`
- `darwin/cachix.nix` lines 57-106: `max-jobs`, `cores`, `keep-outputs`, `trusted-substituters`, `nix.registry.nixpkgs.flake`

**Complete content**:

```nix
# Darwin nix configuration — mirrors modules/base/nix.nix for NixOS.
# Consolidated from darwin/default.nix (experimental features, nix.enable,
# allowUnfree) and darwin/cachix.nix (build optimization, registry).
# All nix.* settings for Darwin hosts live in this single file.
{ lib, inputs, ... }:
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # disabled due to https://github.com/NixOS/nix/issues/7273
      # auto-optimise-store = true;

      # Build parallelism: limit max concurrent jobs to prevent OOM
      # and laptop freezes. `auto` (default) spawns one job per
      # logical core which can blow past available memory when
      # several rustc/ghc/etc instances run simultaneously. mkDefault
      # lets a host bump this without needing mkForce.
      max-jobs = lib.mkDefault 1;

      # All available cores per derivation (-j for make). 0 == all
      # cores. Exposed explicitly for clarity even though it matches
      # the default.
      cores = 0;

      # Retain build outputs across `nix-collect-garbage`. Without
      # this, a package that gets garbage-collected from the store
      # is fully recompiled on the next build, even if its sources
      # haven't changed. Trades ~30% more /nix/store disk for
      # dramatically faster rebuilds.
      keep-outputs = true;

      # Trusted substituters: mirror of the full substituter list so
      # non-root users (e.g. when running `nix shell nixpkgs#foo`
      # unprivileged) can pull from the same binary caches root
      # can. Without this, non-root users are restricted to
      # cache.nixos.org plus any caches they specify explicitly
      # with --option binary-caches.
      trusted-substituters = [
        "https://aseipp-nix-cache.freetls.fastly.net"
        "https://aseipp-nix-cache.global.ssl.fastly.net"
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://ghostty.cachix.org"
        "https://nixpkgs-unfree.cachix.org"
        "https://cache.flox.dev"
        "https://nixpkgs.cachix.org"
      ];
    };
    enable = false; # using Determinate installer

    # Pin the system-wide flake registry so that bare references like
    # `nixpkgs#hello` or `nixpkgs#pkg` resolve to the flake-locked
    # nixpkgs used to build the system, rather than fetching whatever
    # nixos-unstable points at today. This avoids unnecessary network
    # tree fetches and produces reproducible package builds even when
    # the user does not pass `--flake` explicitly. Mirrors
    # `modules/base/nix.nix` on linux.
    registry.nixpkgs.flake = inputs.nixpkgs;
  };

  nixpkgs.config.allowUnfree = true;
}
```

**Why this consolidation matters**: Currently, nix config is split across two files (`default.nix` and `cachix.nix`) with no clear rationale for the split. The NixOS side also has a split (`modules/base/nix.nix` for build opts + registry, `modules/base/cachix.nix` for substituters) but the split is justified: `cachix.nix` on NixOS has its own `options.nix.cachix-custom.enable` toggle. The Darwin side has no such toggle — it always applies. Consolidating all Darwin nix config into one file eliminates the artificial split and makes it trivially discoverable which nix settings a Darwin host gets.

---

### 3. `modules/darwin/system/cachix.nix` (MOVED from `darwin/cachix.nix`)

**Purpose**: Substituters and trusted public keys only. The Fastly mirror priority (`lib.mkBefore`), the full cachix list (`lib.mkAfter`), the trusted public keys, and the `cachix` package.

**Changes from source**: Stripped of lines 57-106 (build optimization: `max-jobs`, `cores`, `keep-outputs`, `trusted-substituters`, `nix.registry.nixpkgs.flake`). These are now in `nix.nix`. The remaining content is the `lib.mkMerge` of substituter/trusted-keys blocks plus `environment.systemPackages = [ cachix ]`.

**Why it stays separate from nix.nix**: The `lib.mkMerge` with `lib.mkBefore`/`lib.mkAfter` for substituter ordering is a distinct concern from the static nix config in `nix.nix`. Keeping this separate makes the substituter priority logic self-contained and easy to review. The NixOS side follows the same pattern: `modules/base/cachix.nix` handles substituters while `modules/base/nix.nix` handles build settings.

**Complete content** (slimmed from 107 lines to ~50 lines):

```nix
# Darwin cachix substituters — mirrors modules/base/cachix.nix for NixOS.
# Moved from darwin/cachix.nix. Contains ONLY substituters, trusted
# public keys, and the cachix package. Build optimization settings
# (max-jobs, cores, keep-outputs, trusted-substituters) and registry
# pinning moved to modules/darwin/system/nix.nix.
{ lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ cachix ];

  # The mkBefore / mkAfter distinction matters for darwin too: future
  # darwin modules may add their own substituters / trusted-public-keys,
  # and we want the fastly mirrors to stay at the top of the lookup
  # order while the rest of the cachix list stays at the bottom. We
  # use lib.mkMerge to declare multiple attrset slices that the NixOS
  # option system combines with the right merge semantics — a single
  # `nix.settings = { ... }` literal cannot have two `substituters`
  # keys (Nix rejects duplicate attribute names).
  nix.settings = lib.mkMerge [
    {
      # Fastly mirrors — same S3-backed nixos cache, different CDN
      # edges. Mirrors `modules/base/nix.nix` (mkBefore) on linux so
      # mact2 benefits from the same lower-latency fetch path.
      substituters = lib.mkBefore [
        "https://aseipp-nix-cache.freetls.fastly.net"
        "https://aseipp-nix-cache.global.ssl.fastly.net"
      ];
    }
    {
      # Full cachix list — mirrors `modules/base/cachix.nix` on
      # linux. The 3 entries beyond cache.nixos.org / nix-community
      # / ghostty are the ones the linux config already pulls
      # (nixpkgs-unfree, flox, nixpkgs). Darwin needs the same
      # coverage to avoid unnecessary source builds on mact2.
      substituters = lib.mkAfter [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "https://ghostty.cachix.org"
        "https://nixpkgs-unfree.cachix.org"
        "https://cache.flox.dev"
        "https://nixpkgs.cachix.org"
      ];
      trusted-public-keys = lib.mkAfter [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZvDo1tvuGySTdw="
        "nix-community.cachix.org-1:7Nw0m1eeP3Gg3RhbC8Vy/Z4GqW2ZJYX9F8Nc8eeeCJ8="
        "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
        "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
        "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
        "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
      ];
    }
  ];
}
```

---

### 4. `modules/darwin/system/homebrew.nix` (MOVED from `darwin/homebrew.nix`)

**Purpose**: Homebrew configuration — taps, brews, casks, activation behavior, cask args. Content unchanged from source.

**Content**: Identical to current `darwin/homebrew.nix` (64 lines). Import path is the only change.

---

### 5. `modules/darwin/system/settings.nix` (MOVED from `darwin/settings.nix`)

**Purpose**: macOS system defaults, SSH configuration, firewall activation scripts, Gatekeeper/trusted-apps scripts, default browser script, postActivation VNC/SMB service management. Content unchanged from source.

**Content**: Identical to current `darwin/settings.nix` (230 lines). Import path is the only change.

---

### 6. `modules/darwin/system/mise.nix` (MOVED from `darwin/mise.nix`)

**Purpose**: Mise tooling activation scripts — Homebrew-mise directory setup, mise linking, global tool declarations (node, bun, go, java), JAVA_HOME symlink. Content unchanged from source.

**Content**: Identical to current `darwin/mise.nix` (84 lines). Import path is the only change.

---

### 7. `modules/darwin/services/wsdd.nix` (MOVED from `darwin/wsdd.nix`)

**Purpose**: WS-Discovery daemon module with `options` + `config` pattern. Declares `options.services.wsdd.*` and wires a `launchd.daemons.wsdd` entry when enabled. Content unchanged from source.

**Why moved to `services/` not `system/`**: wsdd is an optional service (gated by `options.services.wsdd.enable`), not system plumbing. This mirrors the NixOS convention where service modules live in `modules/features/services/` or `modules/virtualisation/`. On the Darwin side, putting it in `services/` leaves room for future Darwin daemon modules.

**Content**: Identical to current `darwin/wsdd.nix` (86 lines). Import path is the only change.

---

### 8. `darwin/default.nix` (REFACTORED)

**Purpose**: Per-host aggregation layer. Imports the darwin profile for system modules and retains only host-specific concerns that vary per Darwin machine: nix-homebrew configuration, home-manager setup, user accounts, environment variables, and service enablements.

**Changes from current (93 lines -> ~55 lines)**:
- Removed individual module imports (`./mise.nix`, `./cachix.nix`, `./homebrew.nix`, `./settings.nix`, `./wsdd.nix`) — replaced by single `../modules/darwin/profiles/base.nix`
- Removed inline `nix.settings` and `nix.enable` block (lines 21-31) — now in `modules/darwin/system/nix.nix`
- Removed `nixpkgs.config.allowUnfree` line (line 33) — now in `modules/darwin/system/nix.nix`
- Kept: `inputs.home-manager.darwinModules.home-manager` and `inputs.nix-homebrew.darwinModules.nix-homebrew` imports
- Kept: `nix-homebrew` config block (lines 36-40)
- Kept: `home-manager` config block (lines 43-66) including `extraSpecialArgs`
- Kept: `system.primaryUser`, `users.users`, `environment.*`, `services.wsdd.enable` (lines 69-92)

**Complete content**:

```nix
# Darwin host configuration for mact2.
# Imports the darwin base profile (system modules) and retains only
# per-host concerns: nix-homebrew, home-manager, users, environment,
# and service enablements.
{ pkgs
, inputs
, self
, primaryUser
, javaVersion
, lib
, ...
}:
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
    ../modules/darwin/profiles/base.nix
  ];

  # homebrew installation manager
  nix-homebrew = {
    user = primaryUser;
    enable = true;
    autoMigrate = true;
  };

  # home-manager config
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # Back up conflicting dotfiles (e.g., ~/.zshrc) instead of failing
    backupFileExtension = "backup";
    users.${primaryUser} = {
      imports = [
        ../home-darwin
      ];
      # Define stateVersion here to satisfy early Home Manager assertions
      home.stateVersion = "25.05";
      # Per-host provider override: mact2 uses GitHub Copilot tier.
      # See `home.opencode.activeProviderName` in shared/opencode.nix.
      home.opencode.activeProviderName = "github-copilot";
    };
    extraSpecialArgs = {
      inherit
        inputs
        self
        primaryUser
        javaVersion
        ;
    };
  };

  # macOS-specific settings
  system.primaryUser = primaryUser;
  users.users.${primaryUser} = {
    home = "/Users/${primaryUser}";
    shell = pkgs.zsh;

    # SSH authorized keys for remote access
    openssh.authorizedKeys.keys = [
      # rog machine (glats)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMigT6lscyISTW6jbk9c34gMYSaRQIq4tUxMvn7vd6K7 t14"
    ];
  };
  environment = {
    variables = {
      DISPLAY = ":0";
    };
    systemPackages = with pkgs; [ git ];
    # Intel uses /usr/local; Apple Silicon uses /opt/homebrew
    systemPath = [
      (if pkgs.stdenv.isAarch64 then "/opt/homebrew/bin" else "/usr/local/bin")
    ];
    pathsToLink = [ "/Applications" ];
  };

  services.wsdd.enable = true;
}
```

---

### 9. `lib/mkDarwinHost.nix` (TRIMMED)

**Purpose**: Builder function for Darwin hosts. Removes the redundant `home-manager.extraSpecialArgs` inline block so that `darwin/default.nix` is the sole owner of that config.

**Changes**: Remove lines 41-52 (the `{ home-manager.extraSpecialArgs = { ... }; }` module block). The `specialArgs` passed to `darwinSystem` (lines 13-23) remain unchanged.

**Before (lines 41-52 being removed)**:
```nix
        # Pass inputs to home-manager for module access
        {
          home-manager.extraSpecialArgs = {
            inherit
              inputs
              self
              username
              ;
            primaryUser = username;
            javaVersion = "temurin-25.0.1+8.0.LTS";
          };
        }
```

**After**:
```nix
{ inputs, self, ... }:

let
  mkDarwinHost =
    { hostname
    , system ? "x86_64-darwin"
    , username ? "jcuzmar"
    , extraModules ? [ ]
    ,
    }:
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = {
        inherit
          inputs
          self
          username
          system
          ;
        host = hostname;
        primaryUser = username;
        javaVersion = "temurin-25.0.1+8.0.LTS";
      };
      modules = [
        # Determinate Nix module
        inputs.determinate.darwinModules.default

        # Host-specific configuration
        ../hosts/${hostname}

        # Darwin system modules (homebrew, settings, etc.)
        ../darwin

        # Overlays for custom packages
        {
          nixpkgs.overlays = [
            (import ../overlays/darwin.nix { inherit inputs self; })
          ];
        }
      ]
      ++ extraModules;
    };
in
{
  inherit mkDarwinHost;
}
```

**Why the NixOS builder (`lib/mkHost.nix`) is NOT changed**: `mkNixosHost` also has an inline `home-manager.extraSpecialArgs` block (lines 34-38 in `lib/mkHost.nix`). Removing that is a separate concern with different risk characteristics — the NixOS Home Manager integration uses `modules/base/home-manager.nix` which also sets `extraSpecialArgs`. Changing both builders simultaneously increases risk. The NixOS builder cleanup is tracked as a future task, not part of this change.

---

### 10. `shared/gpg.nix` (NEW)

**Purpose**: Shared GPG key import function and activation script. Extracts the byte-identical `importKey` function and `home.activation.importGpgKeys` wiring from both `home-linux/gpg.nix` and `home-darwin/gpg.nix`.

**What it contains**: The `importKey` function (identical in both source files) and the `home.activation.importGpgKeys` block that invokes it for `work` and `personal` keys. References `config.sops.secrets.*` paths declared by `shared/sops.nix`. Does NOT set `home.packages` — that stays per-platform.

**Complete content**:

```nix
# Shared GPG key import logic used by both Linux and Darwin Home Manager
# configurations. Extracted from home-linux/gpg.nix and home-darwin/gpg.nix
# (byte-identical in both files).
#
# Does NOT set home.packages — the calling platform module is responsible
# for choosing the appropriate pinentry package.
#
# Depends on shared/sops.nix for secret paths:
#   - github/work_gpg_fingerprint
#   - github/work_gpg_key
#   - github/personal_gpg_fingerprint
#   - github/personal_gpg_key
{ config, lib, pkgs, ... }:

let
  # Import a GPG key from sops secrets into the keyring if not already present.
  importKey = name: fingerprintPath: keyPath: ''
    if [ -f "${fingerprintPath}" ] && [ -f "${keyPath}" ]; then
      FINGERPRINT="$(cat "${fingerprintPath}" | tr -d '\n')"
      if [ -n "$FINGERPRINT" ] && ! ${pkgs.gnupg}/bin/gpg --list-secret-keys "$FINGERPRINT" >/dev/null 2>&1; then
        ${pkgs.gnupg}/bin/gpg --batch --import "${keyPath}"
      fi
    fi
  '';
in
{
  home.activation.importGpgKeys = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (importKey "work"
      config.sops.secrets."github/work_gpg_fingerprint".path
      config.sops.secrets."github/work_gpg_key".path
    + importKey "personal"
      config.sops.secrets."github/personal_gpg_fingerprint".path
      config.sops.secrets."github/personal_gpg_key".path
    );
}
```

---

### 11. `home-linux/gpg.nix` (REFACTORED)

**Purpose**: Linux-specific GPG packages plus shared import logic. Reduced from 28 lines to ~8 lines.

**Changes**: Removed the `importKey` function and `home.activation.importGpgKeys` block (moved to `shared/gpg.nix`). Added import of `../../shared/gpg.nix`. Kept only `home.packages = [ gnupg pinentry-curses ]`.

**Complete content**:

```nix
# Linux GPG configuration — imports shared key logic, sets linux-specific packages.
{ pkgs, ... }:
{
  imports = [ ../../shared/gpg.nix ];

  home.packages = with pkgs; [
    gnupg
    pinentry-curses
  ];
}
```

---

### 12. `home-darwin/gpg.nix` (REFACTORED)

**Purpose**: Darwin-specific GPG packages plus shared import logic. Reduced from 29 lines to ~10 lines.

**Changes**: Removed the `importKey` function and `home.activation.importGpgKeys` block (moved to `shared/gpg.nix`). Added import of `../../shared/gpg.nix`. Kept only `home.packages = [ gnupg pinentry_mac nix-index ]`.

**Complete content**:

```nix
# Darwin GPG configuration — imports shared key logic, sets darwin-specific packages.
{ pkgs, ... }:
{
  imports = [ ../../shared/gpg.nix ];

  home.packages = with pkgs; [
    gnupg
    pinentry_mac
    nix-index
  ];
}
```

---

### 13. `home-darwin/ghostty.nix` (REWRITTEN)

**Purpose**: Migrate from raw `home.file` text config to `programs.ghostty` Home Manager module, matching the Linux pattern. Expands from 50 lines to ~80 lines with the richer `programs.ghostty` attrset.

**Changes**:
- Replace `home.file."Library/Application Support/com.mitchellh.ghostty/config".text` with `programs.ghostty.settings`
- Replace `home.file.".config/ghostty/themes/customColor".text` with `programs.ghostty.themes.nix-colors` using the same palette list syntax as Linux
- Preserve Darwin-specific `macos-option-as-alt = "left"`
- Preserve Darwin-specific `selection-foreground` using `base00` (Linux uses `base05`)
- Add settings from Linux that were missing: `clipboard-paste-protection = false`, `maximize = true`, `keybind`, `term = "xterm-256color"`, `font-size = 11`, `bold-color = "bright"`
- Use the same `#${config.colorScheme.palette.*}` palette mapping format as Linux (with hash prefix)
- Do NOT use `lib.mkForce` (unlike Linux which fights omarchy-nix overrides — Darwin has no competing ghostty module)

**Complete content**:

```nix
# Darwin Ghostty terminal configuration.
# Migrated from raw home.file text to programs.ghostty HM module,
# matching home-linux/ghostty.nix pattern.
# Keeps darwin-specific overrides: macos-option-as-alt, selection-foreground.
{ config, ... }:
{
  programs.ghostty = {
    enable = true;
    settings = {
      bold-color = "bright";
      background-opacity = 0.8;
      clipboard-paste-protection = false;
      clipboard-write = "allow";
      font-family = "CaskaydiaCove Nerd Font";
      font-feature = "+liga";
      font-size = 11;
      keybind = [
        "shift+insert=paste_from_clipboard"
      ];
      macos-option-as-alt = "left";
      maximize = true;
      scrollback-limit = 4294967295;
      term = "xterm-256color";
      theme = "nix-colors";
      window-padding-balance = true;
      window-padding-color = "extend";
    };

    themes = {
      nix-colors = {
        palette = [
          # Normal (0-7)
          "0=#${config.colorScheme.palette.base00}"
          "1=#${config.colorScheme.palette.base08}"
          "2=#${config.colorScheme.palette.base0B}"
          "3=#${config.colorScheme.palette.base0A}"
          "4=#${config.colorScheme.palette.base0D}"
          "5=#${config.colorScheme.palette.base0E}"
          "6=#${config.colorScheme.palette.base0C}"
          "7=#${config.colorScheme.palette.base05}"
          # Bright (8-15)
          "8=#${config.colorScheme.palette.base03}"
          "9=#${config.colorScheme.palette.base08}"
          "10=#${config.colorScheme.palette.base0B}"
          "11=#${config.colorScheme.palette.base0A}"
          "12=#${config.colorScheme.palette.base0D}"
          "13=#${config.colorScheme.palette.base0E}"
          "14=#${config.colorScheme.palette.base0C}"
          "15=#${config.colorScheme.palette.base07}"
          # Extended 256-color space (16-21)
          "16=#${config.colorScheme.palette.base09}"
          "17=#${config.colorScheme.palette.base0F}"
          "18=#${config.colorScheme.palette.base01}"
          "19=#${config.colorScheme.palette.base02}"
          "20=#${config.colorScheme.palette.base04}"
          "21=#${config.colorScheme.palette.base06}"
        ];
        background = "#${config.colorScheme.palette.base00}";
        foreground = "#${config.colorScheme.palette.base05}";
        cursor-color = "#${config.colorScheme.palette.base05}";
        selection-background = "#${config.colorScheme.palette.base02}";
        selection-foreground = "#${config.colorScheme.palette.base00}";
      };
    };
  };
}
```

**Theme palette verification**: The palette mapping is identical between Linux and Darwin except for `selection-foreground`: Darwin uses `base00` (dark background highlight), Linux uses `base05` (light text highlight). This difference is handled via `selectionForegroundPalette` parameter in the shared module (see Component 14).

---

### 14. `shared/ghostty.nix` (NEW — iteration addition)

**Purpose**: Pure Nix function (NOT a HM module) that exports common ghostty settings and the 22-color base16 palette. Eliminates palette duplication between `home-linux/ghostty.nix` and `home-darwin/ghostty.nix`.

**Design constraint**: Zero `isDarwin` conditionals. Platform differences handled via function parameters:
- `extraSettings` — Darwin passes `{ macos-option-as-alt = "left"; }`, Linux omits
- `selectionForegroundPalette` — Darwin passes `"base00"`, Linux uses default `"base05"`

**Complete content**:
```nix
# Shared Ghostty terminal configuration — pure Nix function, NOT a HM module.
#
# Returns { settings, theme } for platform-specific HM modules to consume.
# Platform differences (macos-option-as-alt, selection-foreground, mkForce)
# are handled by the caller, not via conditionals.
#
# Usage:
#   let ghostty = import ../../shared/ghostty.nix { colorScheme = config.colorScheme; };
#   in { programs.ghostty.settings = ghostty.settings; ... }
{ colorScheme
, selectionForegroundPalette ? "base05"
, extraSettings ? {}
}:
let
  p = colorScheme.palette;
in {
  settings = extraSettings // {
    bold-color = "bright";
    background-opacity = 0.8;
    clipboard-paste-protection = false;
    clipboard-write = "allow";
    font-family = "CaskaydiaCove Nerd Font";
    font-feature = "+liga";
    font-size = 11;
    keybind = [
      "shift+insert=paste_from_clipboard"
    ];
    maximize = true;
    scrollback-limit = 4294967295;
    term = "xterm-256color";
    theme = "nix-colors";
    window-padding-balance = true;
    window-padding-color = "extend";
  };
  theme = {
    nix-colors = {
      palette = [
        "0=#${p.base00}"
        "1=#${p.base08}"
        "2=#${p.base0B}"
        "3=#${p.base0A}"
        "4=#${p.base0D}"
        "5=#${p.base0E}"
        "6=#${p.base0C}"
        "7=#${p.base05}"
        "8=#${p.base03}"
        "9=#${p.base08}"
        "10=#${p.base0B}"
        "11=#${p.base0A}"
        "12=#${p.base0D}"
        "13=#${p.base0E}"
        "14=#${p.base0C}"
        "15=#${p.base07}"
        "16=#${p.base09}"
        "17=#${p.base0F}"
        "18=#${p.base01}"
        "19=#${p.base02}"
        "20=#${p.base04}"
        "21=#${p.base06}"
      ];
      background = "#${p.base00}";
      foreground = "#${p.base05}";
      cursor-color = "#${p.base05}";
      selection-background = "#${p.base02}";
      selection-foreground = "#${p.${selectionForegroundPalette}}";
    };
  };
}
```

### 15. `home-linux/ghostty.nix` (REWRITTEN — iteration)

**Purpose**: HM module that imports shared ghostty function and wraps with `lib.mkForce` to override omarchy-nix on t14.

**Complete content**:
```nix
# Linux Ghostty terminal configuration.
# Imports shared ghostty settings + palette. Uses lib.mkForce to override
# omarchy-nix contributions on t14 (settings and themes).
{ config, lib, ... }:
let
  ghostty = import ../../shared/ghostty.nix {
    colorScheme = config.colorScheme;
  };
in {
  programs.ghostty = {
    enable = true;
    settings = lib.mkForce ghostty.settings;
    themes = lib.mkForce ghostty.theme;
  };
}
```

### 16. `home-darwin/ghostty.nix` (REWRITTEN — iteration)

**Purpose**: HM module that imports shared ghostty function and adds Darwin-specific overrides (`macos-option-as-alt`, `selection-foreground = base00`, `package = null`).

**Complete content**:
```nix
# Darwin Ghostty terminal configuration.
# Imports shared ghostty settings + palette. Adds darwin-specific overrides:
# macos-option-as-alt, selection-foreground = base00, package = null (brew).
{ config, ... }:
let
  ghostty = import ../../shared/ghostty.nix {
    colorScheme = config.colorScheme;
    selectionForegroundPalette = "base00";
    extraSettings = { macos-option-as-alt = "left"; };
  };
in {
  programs.ghostty = {
    enable = true;
    package = null;
    settings = ghostty.settings;
    themes = ghostty.theme;
  };
}
```

### Files changed in iteration

| # | File | Action | Est. Lines |
|---|------|--------|------------|
| 19 | `shared/ghostty.nix` | **CREATE** | +55 |
| 20 | `home-linux/ghostty.nix` | **REWRITE** | 80 -> -65 |
| 21 | `home-darwin/ghostty.nix` | **REWRITE** | 72 -> -52 |

**Iteration subtotal**: +55 created, -117 deleted = net -62 lines.

**No-change files**: Both `shared-modules.nix` files (file paths unchanged), `flake.nix`, GPG files, darwin profile chain.

### Before (double-passing)

```
lib/mkDarwinHost.nix
  |
  |--- specialArgs to darwinSystem --> { inputs, self, username, system, host, primaryUser, javaVersion }
  |       |
  |       v
  |    darwin/default.nix  (receives via specialArgs: primaryUser, javaVersion, etc.)
  |       |
  |       |--- home-manager.extraSpecialArgs = { inputs, self, primaryUser, javaVersion }  <-- SOURCE 1
  |       |
  |       v
  |    Home Manager modules (receive extraSpecialArgs from SOURCE 1)
  |
  |--- modules = [ ..., { home-manager.extraSpecialArgs = { inputs, self, username, ... } }, ... ]  <-- SOURCE 2
          |
          v
       Home Manager modules (ALSO receive extraSpecialArgs from SOURCE 2)

   RESULT: Two sources of home-manager.extraSpecialArgs. Nix module system
           merges them, so it "works", but the dual-source pattern is confusing
           and fragile — changing one without changing the other can cause
           silent attribute drift.
```

### After (single ownership)

```
lib/mkDarwinHost.nix
  |
  |--- specialArgs to darwinSystem --> { inputs, self, username, system, host, primaryUser, javaVersion }
  |       |
  |       v
  |    darwin/default.nix  (receives via specialArgs: primaryUser, javaVersion, etc.)
  |       |
  |       |--- home-manager.extraSpecialArgs = { inputs, self, primaryUser, javaVersion }  <-- SOLE SOURCE
  |       |
  |       v
  |    Home Manager modules (receive extraSpecialArgs from single source)

   RESULT: One source of truth. Builder handles system-level concerns (specialArgs
           to darwinSystem). Per-host config (darwin/default.nix) handles
           Home Manager concerns (extraSpecialArgs). Clean separation.
```

## File Change Map

### Area 1: Darwin Profile Chain

| # | File | Action | Content Change | Est. Lines |
|---|------|--------|---------------|------------|
| 1 | `modules/darwin/profiles/base.nix` | **CREATE** | Pure import aggregator (new file) | +15 |
| 2 | `modules/darwin/system/nix.nix` | **CREATE** | Consolidated nix settings from `darwin/default.nix` + `darwin/cachix.nix` (new file) | +70 |
| 3 | `modules/darwin/system/cachix.nix` | **COPY + EDIT** | Copy from `darwin/cachix.nix`; remove build-opt/registry lines (57-106) | Copy 107, -57 |
| 4 | `modules/darwin/system/homebrew.nix` | **COPY** | Copy from `darwin/homebrew.nix`; content unchanged | +64 |
| 5 | `modules/darwin/system/settings.nix` | **COPY** | Copy from `darwin/settings.nix`; content unchanged | +230 |
| 6 | `modules/darwin/system/mise.nix` | **COPY** | Copy from `darwin/mise.nix`; content unchanged | +84 |
| 7 | `modules/darwin/services/wsdd.nix` | **COPY** | Copy from `darwin/wsdd.nix`; content unchanged | +86 |
| 8 | `darwin/default.nix` | **EDIT** | Replace individual imports with `../modules/darwin/profiles/base.nix`; remove `nix.*` inline config | -38, +1 |
| 9 | `darwin/cachix.nix` | **DELETE** | Moved to `modules/darwin/system/cachix.nix` | -107 |
| 10 | `darwin/homebrew.nix` | **DELETE** | Moved to `modules/darwin/system/homebrew.nix` | -64 |
| 11 | `darwin/settings.nix` | **DELETE** | Moved to `modules/darwin/system/settings.nix` | -230 |
| 12 | `darwin/mise.nix` | **DELETE** | Moved to `modules/darwin/system/mise.nix` | -84 |
| 13 | `darwin/wsdd.nix` | **DELETE** | Moved to `modules/darwin/services/wsdd.nix` | -86 |

**Area 1 subtotal**: ~+549 lines created, -609 lines deleted = net -60 lines

### Area 2: mkDarwinHost specialArgs Fix

| # | File | Action | Content Change | Est. Lines |
|---|------|--------|---------------|------------|
| 14 | `lib/mkDarwinHost.nix` | **EDIT** | Remove `{ home-manager.extraSpecialArgs = ... }` block (lines 41-52) | -12 |

**Area 2 subtotal**: -12 lines

### Area 3: GPG + Ghostty Consolidation

| # | File | Action | Content Change | Est. Lines |
|---|------|--------|---------------|------------|
| 15 | `shared/gpg.nix` | **CREATE** | Shared importKey function + activation script (new file) | +30 |
| 16 | `home-linux/gpg.nix` | **EDIT** | Replace content: import shared, keep packages only | -28, +7 |
| 17 | `home-darwin/gpg.nix` | **EDIT** | Replace content: import shared, keep packages only | -29, +8 |
| 18 | `home-darwin/ghostty.nix` | **REWRITE** | Replace `home.file` text with `programs.ghostty` attrset | -50, +78 |

**Area 3 subtotal**: +123 lines created, -107 deleted = net +16 lines

### No-Change Files

| File | Reason |
|------|--------|
| `flake.nix` | `darwinConfigurations.mact2` binding unchanged; `mkDarwinHost` import unchanged |
| `hosts/mact2/default.nix` | 16 lines, sets `networking.hostName` only; no darwin module concerns here |
| `modules/profiles/base.nix` | NixOS side; untouched |
| `modules/base/nix.nix` | NixOS side; untouched |
| `modules/base/cachix.nix` | NixOS side; untouched |
| `lib/mkHost.nix` | NixOS builder; its own `home-manager.extraSpecialArgs` is a separate concern |
| `home-linux/ghostty.nix` | Already in target pattern |
| `home-darwin/shared-modules.nix` | Module list unchanged (gpg.nix and ghostty.nix paths same) |
| `home-linux/shared-modules.nix` | Module list unchanged |
| `shared/opencode.nix`, `shared/sops.nix`, etc. | Shared cross-platform modules; untouched |

### Total Change Summary

| Metric | Count |
|--------|-------|
| Files created | 3 (`base.nix`, `nix.nix`, `gpg.nix`) |
| Files copied (content unchanged) | 4 (`homebrew.nix`, `settings.nix`, `mise.nix`, `wsdd.nix`) |
| Files copied + edited (content reduced) | 1 (`cachix.nix` -- build opts extracted) |
| Files edited | 4 (`darwin/default.nix`, `mkDarwinHost.nix`, `home-linux/gpg.nix`, `home-darwin/gpg.nix`) |
| Files rewritten | 1 (`home-darwin/ghostty.nix`) |
| Files deleted | 5 (`darwin/cachix.nix`, `darwin/homebrew.nix`, `darwin/settings.nix`, `darwin/mise.nix`, `darwin/wsdd.nix`) |
| **Net line change** | **~-56 lines** (creates +672, deletes -728) |

## Migration Path

The migration is structured in three phases that MUST be executed in order. Each phase is independently verifiable.

### Phase 1: Create Directory Structure + New Files (No Breaking Changes)

**Goal**: Create all new files and directories without modifying or deleting any existing files. This is a pure additive step — nothing breaks.

**Steps**:

1. Create directories:
   ```bash
   mkdir -p modules/darwin/profiles
   mkdir -p modules/darwin/system
   mkdir -p modules/darwin/services
   ```

2. Create `modules/darwin/system/nix.nix` (new file — extracted + consolidated nix config)

3. Create `modules/darwin/profiles/base.nix` (new file — pure import aggregator)

4. Create `shared/gpg.nix` (new file — shared GPG import logic)

**Verification**: `nix flake check --no-build darwinConfigurations.mact2`
- Expected: passes (new files exist but nothing imports them yet, so no change in behavior)
- If it fails: new files have syntax errors — fix before proceeding

### Phase 2: Copy Modules to New Location (Dual Existence)

**Goal**: Copy the four unchanged modules to `modules/darwin/system/` and `modules/darwin/services/`. Both old and new files exist. We prepare `darwin/default.nix` to import from the new location but NOT yet modify it.

**Steps**:

5. Copy (not move) `darwin/homebrew.nix` to `modules/darwin/system/homebrew.nix`
6. Copy (not move) `darwin/settings.nix` to `modules/darwin/system/settings.nix`
7. Copy (not move) `darwin/mise.nix` to `modules/darwin/system/mise.nix`
8. Copy (not move) `darwin/wsdd.nix` to `modules/darwin/services/wsdd.nix`
9. Copy `darwin/cachix.nix` to `modules/darwin/system/cachix.nix`, then edit the copy:
   - Remove the `max-jobs`, `cores`, `keep-outputs`, `trusted-substituters`, and `nix.registry.nixpkgs.flake` blocks (lines 57-106)
   - These settings are now in `modules/darwin/system/nix.nix` which was created in Step 2

**Verification**: `nix flake check --no-build darwinConfigurations.mact2`
- Expected: passes (old files in `darwin/` are still imported by `darwin/default.nix`; new files at `modules/darwin/` exist but not yet referenced)
- Confirm copies are byte-identical to original content (except `cachix.nix` which was slimmed)

### Phase 3: Switch Imports + Cleanup + HM Changes

**Goal**: Modify `darwin/default.nix` to import from the new profile, remove old files, trim the builder, and apply HM consolidations. This is the "switchover" step — behavior changes.

**Steps**:

10. Edit `darwin/default.nix`:
    - Replace `./mise.nix`, `./cachix.nix`, `./homebrew.nix`, `./settings.nix`, `./wsdd.nix` imports with `../modules/darwin/profiles/base.nix`
    - Remove `nix = { settings = { ... }; enable = false; };` block (lines 20-31)
    - Remove `nixpkgs.config.allowUnfree = true;` (line 33)
    - These are now provided by `modules/darwin/system/nix.nix` (imported transitively via the profile)

11. Delete old `darwin/*.nix` files:
    ```bash
    rm darwin/cachix.nix darwin/homebrew.nix darwin/settings.nix darwin/mise.nix darwin/wsdd.nix
    ```

12. Edit `lib/mkDarwinHost.nix`:
    - Remove the `{ home-manager.extraSpecialArgs = { ... }; }` block (lines 41-52)
    - The `../darwin` import path is unchanged (still resolves to `darwin/default.nix`)

13. Apply Area 3 HM consolidations:
    - Rewrite `home-darwin/ghostty.nix` with `programs.ghostty` content
    - Rewrite `home-linux/gpg.nix` to import `shared/gpg.nix` + packages only
    - Rewrite `home-darwin/gpg.nix` to import `shared/gpg.nix` + packages only

**Verification**: `nix flake check --no-build`
- Expected: exits 0 for ALL configurations (mact2, rog, thinkcentre, t14)
- If it fails: check for:
  - Import path typos in `modules/darwin/profiles/base.nix`
  - Missing `{ lib, inputs, ... }` parameter in new nix.nix (inputs needed for `nix.registry.nixpkgs.flake`)
  - Home Manager `extraSpecialArgs` still resolving correctly (verify `inputs`, `self`, `primaryUser`, `javaVersion` are all available in `darwin/default.nix`'s scope)
  - Ghostty `programs.ghostty` settings valid (no typos in option names)

## Verification Strategy

### Per-Phase Verification Commands

| Phase | Command | Expected |
|-------|---------|----------|
| 1 (create dirs + new files) | `nix flake check --no-build darwinConfigurations.mact2` | exit 0 |
| 2 (copy modules dual existence) | `nix flake check --no-build darwinConfigurations.mact2` | exit 0 |
| 3 (switch imports + cleanup + HM) | `nix flake check --no-build` | exit 0 for ALL configs |

### Full Verification Checklist

After Phase 3 completion, verify each of these:

1. **Darwin evaluation passes**:
   ```bash
   nix flake check --no-build darwinConfigurations.mact2
   ```
   Expected: exit 0, no evaluation errors.

2. **NixOS hosts unaffected**:
   ```bash
   nix flake check --no-build nixosConfigurations.rog
   nix flake check --no-build nixosConfigurations.thinkcentre
   nix flake check --no-build nixosConfigurations.t14
   ```
   Expected: all exit 0, no changes to NixOS module evaluation.

3. **`darwin/` directory is clean**:
   ```bash
   ls darwin/
   ```
   Expected: only `default.nix` exists. No `cachix.nix`, `homebrew.nix`, `settings.nix`, `mise.nix`, or `wsdd.nix`.

4. **New directories populated**:
   ```bash
   ls modules/darwin/profiles/
   ls modules/darwin/system/
   ls modules/darwin/services/
   ```
   Expected: `base.nix` in profiles; 5 files in system; `wsdd.nix` in services.

5. **`mkDarwinHost.nix` has no duplicate `extraSpecialArgs`**:
   ```bash
   grep -c "home-manager.extraSpecialArgs" lib/mkDarwinHost.nix
   ```
   Expected: 0 (zero matches).

6. **`darwin/default.nix` has single profile import**:
   ```bash
   grep "modules/darwin/profiles/base.nix" darwin/default.nix
   ```
   Expected: exactly one match. No matches for `./mise.nix`, `./cachix.nix`, `./homebrew.nix`, `./settings.nix`, `./wsdd.nix`.

7. **GPG shared module integration**:
   ```bash
   grep "shared/gpg.nix" home-linux/gpg.nix
   grep "shared/gpg.nix" home-darwin/gpg.nix
   grep "importKey" shared/gpg.nix
   ```
   Expected: both platform files import shared; shared file defines `importKey`.

8. **Ghostty module migration**:
   ```bash
   grep "programs.ghostty" home-darwin/ghostty.nix
   grep "home.file" home-darwin/ghostty.nix
   ```
   Expected: `programs.ghostty` matches found; `home.file` NOT found.

9. **Format**:
   ```bash
   format-nix
   ```
   Expected: all new/modified files formatted consistently.

10. **No secrets exposed**:
    ```bash
    git diff --stat
    ```
    Expected: no changes to `secrets/` directory or any plaintext secret values.

### Rollback

If verification fails at any phase and cannot be resolved quickly:

- Phase 1-2 (additive only): Remove created files, delete new directories. No behavioral change to undo.
- Phase 3 (switchover): `git checkout -- darwin/ lib/ home-linux/gpg.nix home-darwin/gpg.nix home-darwin/ghostty.nix` restores all edited files. Delete `modules/darwin/` and `shared/gpg.nix`.

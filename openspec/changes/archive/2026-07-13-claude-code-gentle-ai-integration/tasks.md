# Tasks: Claude Code + Gentle AI Integration

## Dependency Order

Phase order is strict because later phases depend on artifacts created in earlier ones:

1. Phase 1 (gentle-ai-common.nix) must come first — both opencode.nix and claude-code.nix import it.
2. Phase 2 (opencode.nix migration) can run in parallel with Phase 3 (flake/overlays) — they touch disjoint files.
3. Phase 4 (claude-code.nix) depends on Phase 1 (gentle-ai-common.nix) and Phase 3 (flake/overlays for the binary).
4. Phase 5 (claude-code-profile.nix) depends on Phase 4 (option namespace must exist).
5. Phase 6 (shared-modules imports) depends on Phases 4+5 (module files must exist).
6. Phase 7 (verification) depends on all prior phases.

---

## Phase 1: Create `shared/gentle-ai-common.nix`

### 1.1 Rename option in `shared/opencode/mcps-base.nix`: `home.opencode.mcps` -> `home.gentle-ai.mcps`

**File**: `shared/opencode/mcps-base.nix`

Change the option path from `options.home.opencode.mcps` to `options.home.gentle-ai.mcps`. Keep the same default value (`defaultMcps` with 6 MCP servers), same type, same description. The file stays at its current path to minimize churn.

Key edit (line 66):
```nix
# BEFORE:
  options.home.opencode.mcps = mkOption {
# AFTER:
  options.home.gentle-ai.mcps = mkOption {
```

**Rationale**: Ownership moves from OpenCode-specific namespace to shared Gentle AI namespace. Both tools consume from `home.gentle-ai.*`.

**Verification**: `grep -r "home.opencode.mcps" shared/opencode/mcps-base.nix` returns no matches after edit.

---

### 1.2 Rename option in `shared/opencode/mcps.nix`: `home.opencode.extraMcps` -> `home.gentle-ai.extraMcps`

**File**: `shared/opencode/mcps.nix`

Change the option path from `options.home.opencode.extraMcps` to `options.home.gentle-ai.extraMcps`. Also update the description text to remove "home.opencode" reference.

Key edit (line 13):
```nix
# BEFORE:
  options.home.opencode.extraMcps = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule { freeformType = lib.types.attrs; });
    default = { };
    description = "Extra MCP servers merged with home.opencode.mcps.";
# AFTER:
  options.home.gentle-ai.extraMcps = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule { freeformType = lib.types.attrs; });
    default = { };
    description = "Extra MCP servers merged with home.gentle-ai.mcps.";
```

**Verification**: `grep -r "home.opencode" shared/opencode/mcps.nix` returns no matches.

---

### 1.3 Rename option reference in `home-darwin/opencode/mcps-extra.nix`

**File**: `home-darwin/opencode/mcps-extra.nix`

Change the option name on line 70 from `home.opencode.extraMcps` to `home.gentle-ai.extraMcps`. The content stays the same — it sets the same extra MCPs for macOS (drawio, playwright, gcloud, atlassian, chrome-devtools).

Key edit (line 70):
```nix
# BEFORE:
  home.opencode.extraMcps = extraMcps;
# AFTER:
  home.gentle-ai.extraMcps = extraMcps;
```

**Verification**: `grep -r "home.opencode.extraMcps" home-darwin/` returns no matches.

---

### 1.4 Create `shared/gentle-ai-common.nix`

**File**: `shared/gentle-ai-common.nix` (NEW)

A new shared module that defines `home.gentle-ai.*` options. It imports `./opencode/mcps.nix` (which in turn imports `./opencode/mcps-base.nix`) to register the `home.gentle-ai.mcps` and `home.gentle-ai.extraMcps` options. It adds two additional options under `home.gentle-ai`:

- `skillsSource`: path to gentle-ai-assets derivation (default: `"${pkgs.gentle-ai-assets}/share/gentle-ai"`)
- `engramConfig`: attrs for shared Engram defaults (default: `{}`)

Key structure:
```nix
{ config, lib, pkgs, ... }:

with lib;

{
  imports = [
    ./opencode/mcps.nix
  ];

  options.home.gentle-ai = {
    skillsSource = mkOption {
      type = types.path;
      default = "${pkgs.gentle-ai-assets}/share/gentle-ai";
      defaultText = literalExpression ''"${pkgs.gentle-ai-assets}/share/gentle-ai"'';
      description = "Path to Gentle AI assets root (skills, commands, personas, AGENTS.md).";
    };
    engramConfig = mkOption {
      type = types.attrs;
      default = {};
      description = "Shared Engram memory configuration for all tools.";
    };
  };

  # home.gentle-ai.mcps and home.gentle-ai.extraMcps come from mcps.nix import
  config = {};
}
```

Note: `home.gentle-ai.mcps` and `home.gentle-ai.extraMcps` are already defined by the imported `mcps.nix` (via `mcps-base.nix`). This module only adds `skillsSource` and `engramConfig`.

**Verification**: `nix-instantiate --eval --expr '(import ./shared/gentle-ai-common.nix { config = {}; lib = import <nixpkgs/lib>; pkgs = {}; }).options.home.gentle-ai'` parses successfully. Or use `nix flake check --no-build` after importing in a host.

---

## Phase 2: Migrate `shared/opencode.nix` to use gentle-ai-common

### 2.1 Add gentle-ai-common import to opencode.nix, remove direct mcps.nix import

**File**: `shared/opencode.nix`

Change the `imports` block (lines 293-298) to import `./gentle-ai-common.nix` instead of `./opencode/mcps.nix`:

Key edits:
```nix
# BEFORE (lines 293-298):
  imports = [
    ./opencode/agents.nix
    ./opencode/mcps.nix
    ./opencode/permissions.nix
    ./opencode/plugins.nix
  ];

# AFTER:
  imports = [
    ./gentle-ai-common.nix
    ./opencode/agents.nix
    ./opencode/permissions.nix
    ./opencode/plugins.nix
  ];
```

---

### 2.2 Update MCP reference in mkRuntimeConfig from `cfg.mcps` to `config.home.gentle-ai.mcps`

**File**: `shared/opencode.nix`

Change the MCP merge expression in `mkRuntimeConfig` (line 27) from reading `cfg.mcps // cfg.extraMcps` to reading from `config.home.gentle-ai.*`. The `cfg` variable is `config.home.opencode` and does NOT have `mcps` or `extraMcps` anymore.

Key edit (around line 27):
```nix
# BEFORE:
      allMcps = cfg.mcps // cfg.extraMcps;

# AFTER:
      allMcps = config.home.gentle-ai.mcps // config.home.gentle-ai.extraMcps;
```

**Also verify** there are no other references to `cfg.mcps` or `cfg.extraMcps` elsewhere in the file. If references exist in the json generation or anywhere else in `mkRuntimeConfig`, change them all to `config.home.gentle-ai.mcps` / `config.home.gentle-ai.extraMcps`.

---

### 2.3 Update skills source reference in opencode.nix activation script

**File**: `shared/opencode.nix`

In the activation script, the skills/commands source path is hardcoded as `${pkgs.gentle-ai-assets}/share/gentle-ai`. Consider whether to keep the hardcoded path or read from `config.home.gentle-ai.skillsSource`. For this migration, keep the hardcoded path (minimal change) — the option exists for future flexibility.

**No code change needed** — just verify that the activation script still references the correct path.

**Verification**: `grep -c "config.home.gentle-ai" shared/opencode.nix` returns at least 2 (mcps and extraMcps). `grep -c "cfg.mcps\|cfg.extraMcps" shared/opencode.nix` returns 0.

---

## Phase 3: Flake input + overlays for Claude Code binary

### 3.1 Add `claude-code-nix` flake input

**File**: `flake.nix`

Add a new input block for `sadjow/claude-code-nix` after the `engram-src` block (after line 58). Use `follows = false` (no Nixpkgs follows since the source is a Nix overlay that fetches a binary).

Key insertion (after `engram-src` block):
```nix
    # Claude Code binary from Nix overlay (auto-updating from Anthropic's releases)
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      # No nixpkgs follow — the overlay provides the binary directly
    };
```

**Verify**: `nix flake lock --update-input claude-code-nix` works (if input already added). Otherwise check syntax with `nix flake check --no-build`.

---

### 3.2 Wire `claude-code` into `overlays/linux.nix`

**File**: `overlays/linux.nix`

The `linux.nix` overlay receives `{ self, inputs }` as arguments. Add `claude-code` to the `inherit (self.packages.${prev.stdenv.hostPlatform.system})` block (around line 9-21). The binary comes from `inputs.claude-code-nix.packages.${prev.stdenv.hostPlatform.system}.claude-code`, but we pipe it through `self.packages` (defined in `lib/packages.nix`) so both overlays reference the same source.

Key additions to the inherit block (line 9):
```nix
  # BEFORE:
  inherit (self.packages.${prev.stdenv.hostPlatform.system})
    nixos-scripts
    ...
    openfang
    ;

  # AFTER:
  inherit (self.packages.${prev.stdenv.hostPlatform.system})
    nixos-scripts
    ...
    openfang
    claude-code
    ;
```

---

### 3.3 Wire `claude-code` into `overlays/darwin.nix`

**File**: `overlays/darwin.nix`

Same addition as 3.2 but in the darwin overlay. Add `claude-code` to the `inherit (self.packages.${system})` block (around line 29-40).

Key addition to the inherit block:
```nix
  # BEFORE:
  inherit (self.packages.${system})
    nixos-scripts
    ...
    opencode
    ;

  # AFTER:
  inherit (self.packages.${system})
    nixos-scripts
    ...
    opencode
    claude-code
    ;
```

---

### 3.4 Add `claude-code` to `lib/packages.nix`

**File**: `lib/packages.nix`

Add `claude-code = linuxPkgs.inputs.claude-code-nix.packages.x86_64-linux.claude-code;` to both `linuxPackages` and `darwinPackages` blocks. Since `claude-code-nix` provides the package directly (not via callPackage), use `inputs.claude-code-nix.packages.<system>.claude-code`.

Key additions:
```nix
  # In linuxPackages block (after line 58):
    claude-code = linuxPkgs.inputs.claude-code-nix.packages.x86_64-linux.claude-code;

  # In darwinPackages block (after line 92):
    claude-code = darwinPkgs.inputs.claude-code-nix.packages.x86_64-darwin.claude-code;
```

**Verification**: `grep -c "claude-code" overlays/linux.nix overlays/darwin.nix lib/packages.nix` returns 1 match in each file.

---

## Phase 4: Create `shared/claude-code.nix` (main module)

### 4.1 Create module skeleton with options and gentle-ai-common import

**File**: `shared/claude-code.nix` (NEW)

Create the main Claude Code HM module. Structure mirrors `shared/opencode.nix` but for `~/.claude/`. Imports `./gentle-ai-common.nix` to access `home.gentle-ai.*` options. Defines its own `home.claude-code` options.

```nix
{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.home.claude-code;
  gentleAi = config.home.gentle-ai;
  claudeDir = "${config.home.homeDirectory}/.claude";

  # MCP translation: OpenCode format -> Claude Code .mcp.json format
  translateMcpToClaude = name: mcp:
    if mcp.type == "local" then {
      type = "stdio";
      command = builtins.head mcp.command;
      args = builtins.tail mcp.command;
    } else if mcp.type == "remote" then {
      type = "http";
      inherit (mcp) url;
    } else throw "claude-code: unknown MCP type for ${name}";

  # Collect all enabled MCPs and translate
  allMcps = gentleAi.mcps // gentleAi.extraMcps;
  enabledMcps = lib.filterAttrs (name: mcp: mcp.enabled or false) allMcps;
  claudeMcps = lib.mapAttrs translateMcpToClaude enabledMcps;
in {
  imports = [
    ./gentle-ai-common.nix
  ];

  options.home.claude-code = {
    enable = mkEnableOption "Claude Code runtime with Gentle AI assets";
    model = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Default Claude Code model ID. Null uses CLI default.";
    };
    permissions = mkOption {
      type = types.attrs;
      default = {};
      description = "Permissions block for settings.json (e.g., { allow = []; deny = []; }.";
    };
    extraClaudeMcps = mkOption {
      type = types.attrsOf (types.submodule { freeformType = types.attrs; });
      default = {};
      description = "Additional MCPs in Claude Code format (not translated from gentle-ai).";
    };
    defaultMode = mkOption {
      type = types.str;
      default = "default";
      description = "Default Claude Code mode (e.g., default, architect, edit).";
    };
  };
  # ... config block follows in sub-tasks
}
```

**Verification**: file exists and parses (syntax check with `nix-instantiate --parse`).

---

### 4.2 Add home.packages to install claude-code binary

**File**: `shared/claude-code.nix`

Add to the `config` block (inside `mkIf cfg.enable`):

```nix
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      claude-code  # from overlay, resolves via pkgs
    ];
```

Note: `claude-code` is available via `pkgs.claude-code` because the overlays add it to the package set.

---

### 4.3 Generate `.mcp.json` with translated MCPs

**File**: `shared/claude-code.nix`

Add `home.file` entry for `.mcp.json`:

```nix
    home.file = {
      ".claude/.mcp.json" = {
        force = true;
        text = builtins.toJSON {
          mcpServers = claudeMcps // cfg.extraClaudeMcps;
        };
      };
      # Next sub-tasks add more home.file entries
    };
```

The MCP JSON format for Claude Code is:
```json
{
  "mcpServers": {
    "github-personal": {
      "type": "stdio",
      "command": "github-mcp-server-personal",
      "args": ["stdio"]
    },
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp"
    }
  }
}
```

---

### 4.4 Generate `settings.json` with permissions and model defaults

**File**: `shared/claude-code.nix`

Add a `home.file` symlink for `settings.json`, then an activation script to convert it to a writable real copy (same pattern as OpenCode's `makeOpencodeConfigMutable`).

```nix
      ".claude/settings.json" = {
        force = true;
        text = builtins.toJSON (
          {
            permissions = cfg.permissions;
          }
          // lib.optionalAttrs (cfg.model != null) { model = cfg.model; }
          // lib.optionalAttrs (cfg.defaultMode != "default") { defaultMode = cfg.defaultMode; }
        );
      };
```

Activation script entry (after `home.file` block):

```nix
    home.activation."makeClaudeConfigMutable" =
      config.lib.dag.entryAfter [ "linkGeneration" ]
        ''
          claude_dir="${claudeDir}"

          if [ ! -d "$claude_dir" ]; then
            mkdir -p "$claude_dir"
          fi

          # Convert .mcp.json symlink -> real copy
          for file in .mcp.json settings.json; do
            target="$claude_dir/$file"
            if [ -L "$target" ]; then
              src="$(${pkgs.coreutils}/bin/readlink -f "$target")"
              ${pkgs.coreutils}/bin/cp --remove-destination "$src" "$target"
            fi
            # Ensure writable
            if [ -f "$target" ] && [ ! -w "$target" ]; then
              chmod 644 "$target"
            fi
          done
        '';
```

---

### 4.5 Deploy skills to `~/.claude/skills/` with cmp-guarded copy + orphan cleanup

**File**: `shared/claude-code.nix`

Add to the activation script (same `makeClaudeConfigMutable` or a separate `syncClaudeSkills` activation hook). This mirrors the OpenCode skill sync pattern exactly but targets `~/.claude/skills/`.

```nix
    home.activation."syncClaudeSkills" =
      config.lib.dag.entryAfter [ "makeClaudeConfigMutable" ]
        ''
          src="${gentleAi.skillsSource}/skills"
          target="${claudeDir}/skills"

          if [ -L "$target" ]; then
            ${pkgs.coreutils}/bin/rm -f "$target"
          fi
          mkdir -p "$target"

          # Copy changed files with cmp guard
          (cd "$src" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
            if [ ! -f "$target/$rel" ] || ! ${pkgs.diffutils}/bin/cmp -s "$src/$rel" "$target/$rel"; then
              mkdir -p "$(dirname "$target/$rel")"
              ${pkgs.coreutils}/bin/cp -f "$src/$rel" "$target/$rel"
              chmod 644 "$target/$rel"
            fi
          done

          # Remove orphaned files
          (cd "$target" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
            if [ ! -f "$src/$rel" ]; then
              rm -f "$target/$rel"
            fi
          done
        '';
```

---

### 4.6 Deploy commands to `~/.claude/commands/`

**File**: `shared/claude-code.nix`

Add to the same activation script or a chained hook after `syncClaudeSkills`. Source is `${gentleAi.skillsSource}/claude/commands/`.

```nix
          # Deploy slash commands to ~/.claude/commands/
          commands_src="${gentleAi.skillsSource}/claude/commands"
          commands_target="${claudeDir}/commands"

          if [ -d "$commands_src" ]; then
            if [ -L "$commands_target" ]; then
              ${pkgs.coreutils}/bin/rm -f "$commands_target"
            fi
            mkdir -p "$commands_target"

            (cd "$commands_src" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
              if [ ! -f "$commands_target/$rel" ] || ! ${pkgs.diffutils}/bin/cmp -s "$commands_src/$rel" "$commands_target/$rel"; then
                mkdir -p "$(dirname "$commands_target/$rel")"
                ${pkgs.coreutils}/bin/cp -f "$commands_src/$rel" "$commands_target/$rel"
                chmod 644 "$commands_target/$rel"
              fi
            done

            (cd "$commands_target" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
              if [ ! -f "$commands_src/$rel" ]; then
                rm -f "$commands_target/$rel"
              fi
            done
          fi
```

---

### 4.7 Deploy personas to `~/.claude/personas/`

**File**: `shared/claude-code.nix`

Add to activation. Source is `${gentleAi.skillsSource}/claude/personas/`. Same cmp-guarded copy + orphan cleanup pattern.

```nix
          personas_src="${gentleAi.skillsSource}/claude/personas"
          personas_target="${claudeDir}/personas"

          if [ -d "$personas_src" ]; then
            if [ -L "$personas_target" ]; then
              ${pkgs.coreutils}/bin/rm -f "$personas_target"
            fi
            mkdir -p "$personas_target"

            (cd "$personas_src" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
              if [ ! -f "$personas_target/$rel" ] || ! ${pkgs.diffutils}/bin/cmp -s "$personas_src/$rel" "$personas_target/$rel"; then
                mkdir -p "$(dirname "$personas_target/$rel")"
                ${pkgs.coreutils}/bin/cp -f "$personas_src/$rel" "$personas_target/$rel"
                chmod 644 "$personas_target/$rel"
              fi
            done

            (cd "$personas_target" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
              if [ ! -f "$personas_src/$rel" ]; then
                rm -f "$personas_target/$rel"
              fi
            done
          fi
```

---

### 4.8 Generate `~/.claude/CLAUDE.md` from AGENTS.md

**File**: `shared/claude-code.nix`

Add as a `home.file` entry or as part of the activation script. Using `home.file` with `force = true` is simplest. Source is `${gentleAi.skillsSource}/AGENTS.md`.

```nix
      ".claude/CLAUDE.md" = {
        force = true;
        source = "${gentleAi.skillsSource}/AGENTS.md";
      };
```

Then in the activation script, convert the symlink to a writable copy (already handled by the `makeClaudeConfigMutable` loop over all files, or add CLAUDE.md to the loop).

---

## Phase 5: Create `shared/claude-code-profile.nix`

### 5.1 Create profile with default enablement

**File**: `shared/claude-code-profile.nix` (NEW)

Default profile that enables Claude Code on all hosts. Similar pattern to `shared/opencode-profile.nix`.

```nix
{ lib, ... }:

{
  home.claude-code = {
    enable = true;

    # Default permissions: allow all for now. Per-host overrides restrict as needed.
    permissions = {
      allow = [ "*" ];
    };

    # Model: null means use CLI default (Claude 4 Sonnet as of latest)
    model = lib.mkDefault null;

    # Default mode
    defaultMode = "default";
  };
}
```

**Note**: `model = null` means the CLI default applies (Anthropic's latest model at login time). Per-host overrides can pin a specific model.

**Verification**: `nix-instantiate --parse shared/claude-code-profile.nix` succeeds.

---

## Phase 6: Import claude-code modules in shared-modules lists

### 6.1 Add claude-code imports to `home-linux/shared-modules.nix`

**File**: `home-linux/shared-modules.nix`

Append two lines after the `opencode-profile.nix` entry (after line 34):

```nix
  ../shared/claude-code.nix
  ../shared/claude-code-profile.nix
```

The block after addition (lines 32-35):
```nix
  ../shared/opencode.nix
  ../shared/opencode-profile.nix
  ../shared/claude-code.nix
  ../shared/claude-code-profile.nix
```

This affects hosts: rog, thinkcentre, t14 (all Linux hosts using this shared module list).

---

### 6.2 Add claude-code imports to `home-darwin/shared-modules.nix`

**File**: `home-darwin/shared-modules.nix`

Append the same two entries after the `opencode-profile.nix` entry (after line 33):

```nix
  ../shared/claude-code.nix
  ../shared/claude-code-profile.nix
```

The block after addition (lines 32-35):
```nix
  ../shared/opencode.nix
  ../shared/opencode-profile.nix
  ../shared/claude-code.nix
  ../shared/claude-code-profile.nix
```

This affects: mact2 (darwin).

---

## Phase 7: Verification

### 7.1 Run formatter on all changed files

```bash
# Run repo-wide formatter
format-nix

# Check diff is clean (only expected formatting changes)
git diff --stat
```

---

### 7.2 Run `nix flake check --no-build` for at least one host

```bash
# Check all NixOS hosts
nix flake check --no-build
```

Expected: passes for all hosts. If an unrelated host fails, confirm it is pre-existing (not caused by this change).

---

### 7.3 Verify option names are consistent

Check that no stale `home.opencode.mcps` or `home.opencode.extraMcps` references remain (except the co-located OpenCode-specific options like `home.opencode.permissions` which are intentionally unchanged):

```bash
# Should return ONLY the OpenCode-specific options (permissions, agents, plugins, etc.)
# NOT the migrated MCP options
rg "home\.opencode\." shared/ shared/opencode/ --no-filename | sort -u
```

Expected remaining `home.opencode.*` options (unchanged, not migrated):
- `home.opencode.enable`
- `home.opencode.disabledProviders`
- `home.opencode.extraInitContent`
- `home.opencode.activeProviderName`
- `home.opencode.permissions` (from `shared/opencode/permissions.nix`)
- `home.opencode.agents` (from `shared/opencode/agents.nix`)
- `home.opencode.plugins` (from `shared/opencode/plugins.nix`)
- `home.opencode.tuiPlugins` (from `shared/opencode/plugins.nix`)

`home.opencode.mcps` and `home.opencode.extraMcps` should appear NOWHERE.

---

### 7.4 Verify claude-code builds (Linux path)

```bash
# Build the claude-code module by checking a host config compiles
nix build .#nixosConfigurations.rog.config.system.build.toplevel
```

If this succeeds, the module is valid and all options resolve.

---

### 7.5 Verify claude-code builds (Darwin path)

```bash
# Build the darwin HM activation package
nix build .#homeConfigurations.mact2.activationPackage
```

---

### 7.6 Verify OpenCode is not broken

```bash
# Build opencode activation on the same Linux host
nix build .#homeConfigurations.rog.activationPackage
```

This must succeed and include the `makeOpencodeConfigMutable` activation script (not broken by the option rename).

---

### 7.7 Manual runtime verification checklist

After deploying to any host, verify:

| Check | Command |
|-------|---------|
| Binary on PATH | `which claude` |
| Binary version | `claude --version` |
| Skills deployed | `ls ~/.claude/skills/` |
| MCP config exists | `cat ~/.claude/.mcp.json` |
| Settings writable | `[ -w ~/.claude/settings.json ] && echo "writable"` |
| CLAUDE.md exists | `cat ~/.claude/CLAUDE.md` |
| Commands deployed | `ls ~/.claude/commands/` |
| Personas deployed | `ls ~/.claude/personas/` |
| OpenCode intact | `ls ~/.config/opencode/skills/` (same output as before) |
| MCP count | `jq '.mcpServers | keys | length' ~/.claude/.mcp.json` (should be 6 + any darwin extras) |

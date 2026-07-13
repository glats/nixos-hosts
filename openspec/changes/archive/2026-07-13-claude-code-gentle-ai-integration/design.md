# Design: Claude Code + Gentle AI Integration

## Technical Approach

Deploy Claude Code on all 4 hosts via a shared `home.gentle-ai.*` option namespace that neither OpenCode nor Claude Code "owns." A new `shared/gentle-ai-common.nix` module defines MCPs, skills source, and other shared concerns. Both `shared/opencode.nix` and `shared/claude-code.nix` import it and consume from `config.home.gentle-ai.*` — no cross-dependency between tool modules. The `claude-code` binary comes from `sadjow/claude-code-nix` flake input, wired through overlays. Auth is OAuth `/login`.

## Architecture Decisions

### Decision: Shared gentle-ai-common module owns MCP definitions

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Claude reads `home.opencode.mcps` (original design) | Couples claude-code to opencode; rejected by user | Rejected |
| Duplicate MCPs in `claude-code/mcps-base.nix` | Risk of drift between tools | Rejected |
| New `home.gentle-ai.*` namespace in shared module | Clean separation; both tools consume independently | **Chosen** |

**Rationale**: User explicitly rejected cross-dependency ("No quiero ver herencia de opencode en claude como 'lee home.opencode.mcps'"). `gentle-ai-common.nix` defines `home.gentle-ai.mcps`, `home.gentle-ai.extraMcps`, `home.gentle-ai.skillsSource`. Both tools import it; neither owns the common config. Same pattern extends to future tools (cursor, gemini).

### Decision: mcps-base.nix stays in shared/opencode/ but defines home.gentle-ai.mcps

**Choice**: `shared/opencode/mcps-base.nix` changes its option from `home.opencode.mcps` to `home.gentle-ai.mcps`. File stays in current path to minimize churn. `mcps.nix` changes `home.opencode.extraMcps` to `home.gentle-ai.extraMcps`. Both are imported by `gentle-ai-common.nix`, not by `opencode.nix` directly.

### Decision: Binary via flake input, not nixpkgs

**Choice**: `claude-code = inputs.claude-code-nix.packages.${system}.claude-code` in overlays.
**Rationale**: `sadjow/claude-code-nix` updates hourly from Anthropic's native releases. Pinned by `flake.lock` — deterministic per build.

### Decision: Settings.json as writable real copy via activation

**Choice**: Generate `settings.json` with `home.file` (symlink), then convert to real file in activation (`cp --remove-destination` + `chmod 644`). Same pattern as `opencode.json` in `makeOpencodeConfigMutable`.
**Rationale**: Claude Code writes to `settings.json` at runtime. Spec R4 requires "writable copy, not symlink."

## Data Flow

```
flake.nix inputs
  ├ claude-code-nix ─→ overlays/{linux,darwin}.nix ─→ home.packages
  └ gentle-ai-src/engram-src/caveman-src (existing)

shared/gentle-ai-common.nix  (NEW — shared module)
  ├ imports ./opencode/mcps.nix ─→ ./opencode/mcps-base.nix
  │   (defines home.gentle-ai.mcps + home.gentle-ai.extraMcps)
  ├ defines home.gentle-ai.skillsSource (path → gentle-ai-assets)
  └ defines home.gentle-ai.engramConfig (shared engram defaults)
        │
  ┌─────┴──────────────────────────┐
  ▼                                ▼
shared/opencode.nix            shared/claude-code.nix  (NEW)
  imports gentle-ai-common       imports gentle-ai-common
  reads home.gentle-ai.mcps      reads home.gentle-ai.mcps
  generates opencode.json        generates .mcp.json + settings.json
  NO home.opencode.mcps           NO dependency on home.opencode.*

home.gentle-ai.mcps (base 6) + home.gentle-ai.extraMcps (darwin extras)
     │  filter enabled; translate per tool format
     ▼
  opencode: { name: {type,command,url,...} }
  claude:    .mcp.json = { "mcpServers": { name: {type,command?,args?,url?} } }

home.gentle-ai.skillsSource
     │
     ├→ opencode activation: skills/, commands/ → ~/.config/opencode/
     └→ claude activation:  skills/, commands/, personas/ → ~/.claude/
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `shared/gentle-ai-common.nix` | Create | Shared module: `home.gentle-ai.mcps`, `.extraMcps`, `.skillsSource`, `.engramConfig`. Imports `./opencode/mcps.nix` |
| `shared/opencode/mcps-base.nix` | Modify | Option renamed `home.opencode.mcps` → `home.gentle-ai.mcps` (same 6 defaults) |
| `shared/opencode/mcps.nix` | Modify | Option renamed `home.opencode.extraMcps` → `home.gentle-ai.extraMcps` |
| `shared/opencode.nix` | Modify | Import `./gentle-ai-common.nix`; remove `./opencode/mcps.nix` from imports; read `config.home.gentle-ai.mcps // config.home.gentle-ai.extraMcps` instead of `cfg.mcps // cfg.extraMcps` |
| `shared/claude-code.nix` | Create | HM module: `home.claude-code.*` options, `translateMcpToClaude`, settings.json/.mcp.json generation, activation for skills/commands/personas/CLAUDE.md |
| `shared/claude-code-profile.nix` | Create | Defaults: `home.claude-code.enable = true`, permission defaults, `defaultMode = "default"` |
| `home-darwin/opencode/mcps-extra.nix` | Modify | `home.opencode.extraMcps` → `home.gentle-ai.extraMcps` |
| `flake.nix` | Modify | Add `claude-code-nix` input after `gentle-ai-src` block |
| `overlays/linux.nix` | Modify | Add `claude-code` to inherit block |
| `overlays/darwin.nix` | Modify | Same addition |
| `home-linux/shared-modules.nix` | Modify | Append `../shared/claude-code.nix` + `../shared/claude-code-profile.nix` after opencode entries |
| `home-darwin/shared-modules.nix` | Modify | Same two imports |

**Hosts affected**: all 4 — `rog`, `thinkcentre`, `t14` (Linux via `home-linux/shared-modules.nix`); `mact2` (Darwin via `home-darwin/shared-modules.nix`).

**No changes to**: `hosts/*/default.nix` (no `home.opencode.mcps` references found in any host), `secrets/`, `pkgs/gentle-ai-assets/*`, `lib/packages.nix`.

**No changes to**: `shared/opencode/permissions.nix` (permissions are OpenCode-specific format, stays as `home.opencode.permissions`), `shared/opencode/agents.nix`, `shared/opencode/plugins.nix`.

## Interfaces / Contracts

```nix
# shared/gentle-ai-common.nix
options.home.gentle-ai = {
  mcps = mkOption {
    type = types.attrsOf (types.submodule { freeformType = types.attrs; });
    default = (import ./opencode/mcps-base.nix defaultMcps);  # same 6 defaults
  };
  extraMcps = mkOption { type = types.attrsOf ...; default = {}; };
  skillsSource = mkOption {
    type = types.path;
    default = "${config.lib.meta.pkgs.gentle-ai-assets}/share/gentle-ai";
  };
  engramConfig = mkOption { type = types.attrs; default = {}; };
};

# shared/claude-code.nix
options.home.claude-code = {
  enable = mkEnableOption "Claude Code runtime with Gentle AI assets";
  model = mkOption { type = types.nullOr types.str; default = null; };
  permissions = mkOption { type = types.submodule { ... }; default = {}; };
  extraClaudeMcps = mkOption { type = types.attrsOf ...; default = {}; };
};
```

MCP translation (pure function in `claude-code.nix`):

```nix
translateMcpToClaude = name: mcp:
  if mcp.type == "local"  then { type = "stdio"; command = builtins.head mcp.command; args = builtins.tail mcp.command; }
  else if mcp.type == "remote" then { type = "http"; inherit (mcp) url; }
  else throw "claude-code: unknown MCP type for ${name}";
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Static | `nix flake check --no-build` passes for all hosts after `format-nix` | Syntax + option validation (only available test) |
| Build | `nix build .#nixosConfigurations.rog.config.system.build.toplevel`; `nix build .#homeConfigurations.mact2.activationPackage` | Linux + Darwin paths compile with new modules |
| Runtime (manual) | `claude --version` on PATH; `~/.claude/skills/`, `.mcp.json`, `settings.json`, `CLAUDE.md` exist; OpenCode unchanged | Manual verification per success criteria |

## Migration / Rollout

**Migration**: `home.opencode.mcps` is deprecated; all references migrate to `home.gentle-ai.mcps`. Only 3 files reference the old option: `mcps-base.nix`, `mcps.nix`, `home-darwin/opencode/mcps-extra.nix`. No host files set `home.opencode.mcps` directly — migration is contained to shared modules.

**Rollout**: Rebuild each host. First `claude` invocation triggers OAuth `/login` (browser-based, one-time). On headless `thinkcentre`, use `claude setup-token` from a browser host.

**Rollback**: Remove claude imports from `shared-modules.nix` files, revert `gentle-ai-common.nix` import in `opencode.nix`, restore old `home.opencode.mcps` option names, rebuild. OpenCode is unaffected by claude-code removal since it reads from `home.gentle-ai.*` which still exists.

## Open Questions

- [ ] Should `mcps-base.nix` and `mcps.nix` be physically moved to `shared/gentle-ai/` to reflect new ownership, or kept in `shared/opencode/` to minimize git diff churn? Design assumes stay (user table says "REMAINS").
- [ ] Headless `thinkcentre` OAuth: confirm `claude setup-token` flow works, or whether a sops secret for the token is needed.
- [ ] Whether `home.claude-code.model` should default to a specific model ID or stay null (CLI default).
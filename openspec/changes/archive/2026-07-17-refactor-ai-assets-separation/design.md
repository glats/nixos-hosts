# Design: Refactor AI assets separation — independent skill sources

## Technical Approach

Split the monolithic `gentle-ai-assets-vanilla`→`gentle-ai-assets` chain into independent per-source derivations. Activation generalizes from 2-pass fixed patterns to N-way bash loops. The `extraAssets`/`extraFiles` overlay is removed; local overrides use `home.file` with `./`-relative source paths.

## Architecture Decisions

| Decision | Options | Choice | Rationale |
|----------|---------|--------|-----------|
| Merge strategy | Nix derivation merge vs bash union | **N-way bash union** | Already a 2-source union pattern; generalizing to N mirrors existing code. Nix merge re-creates the monolith we're escaping. |
| Local overrides | Via `local-ai-assets` vs direct `home.file` | **`home.file` with `./` paths** | Only 1 override (review-gate.md). `local-ai-assets` is for skills, not single-file overrides. |
| AGENTS.md concat | Nix `runCommand` vs bash `cat` | **bash `cat` in activation** | Same activation that deploys skills also handles AGENTS.md. Avoids extra derivation. Concat is trivial (literally `>` then `cat` loop). |
| Claude Code review-gate | New derivation vs reuse opencode version | **Reuse `./shared/opencode/assets/opencode/review-gate.md`** | The 443-line orchestrator version is canonical. Delete the redundant 18-line version. |

## Derivation Designs

### `pkgs/gentle-ai-assets/default.nix` (rewritten)
Pure gentle-ai-src, no caveman/ponytail. Output: `$out/share/gentle-ai/`

```nix
{ lib, stdenvNoCC, gentle-ai-src }:
stdenvNoCC.mkDerivation {
  pname = "gentle-ai-assets"; version = gentle-ai-src.rev or "unstable";
  src = gentle-ai-src;
  installPhase = ''
    mkdir -p $out/share/gentle-ai
    [ -f $src/AGENTS.md ] && cp $src/AGENTS.md $out/share/gentle-ai/
    for dir in opencode skills claude cursor windsurf gemini codex kimi qwen kiro; do
      if [ -d $src/internal/assets/$dir ]; then
        mkdir -p $out/share/gentle-ai/$dir
        cp -r $src/internal/assets/$dir/* $out/share/gentle-ai/$dir/
      fi
    done
    # root-level skills (if any exist alongside internal/assets/skills)
    if [ -d $src/skills ]; then
      mkdir -p $out/share/gentle-ai/skills
      cp -r $src/skills/* $out/share/gentle-ai/skills/ 2>/dev/null || true
    fi
  '';
}
```

### `pkgs/caveman-assets/default.nix` (new)
caveman-src only. Output: `$out/share/caveman/`

```nix
{ lib, stdenvNoCC, caveman-src }:
stdenvNoCC.mkDerivation {
  pname = "caveman-assets"; version = caveman-src.rev or "unstable";
  src = caveman-src;
  installPhase = ''
    mkdir -p $out/share/caveman
    [ -d $src/skills ] && mkdir -p $out/share/caveman/skills && cp -r $src/skills/* $out/share/caveman/skills/
    [ -d $src/commands ] && mkdir -p $out/share/caveman/commands && cp -r $src/commands/* $out/share/caveman/commands/
  '';
}
```

### `pkgs/ponytail-assets/default.nix` (new)
ponytail-src only. Output: `$out/share/ponytail/`

```nix
{ lib, stdenvNoCC, ponytail-src }:
stdenvNoCC.mkDerivation {
  pname = "ponytail-assets"; version = ponytail-src.rev or "unstable";
  src = ponytail-src;
  installPhase = ''
    mkdir -p $out/share/ponytail
    [ -d $src/skills ] && mkdir -p $out/share/ponytail/skills && cp -r $src/skills/* $out/share/ponytail/skills/
    [ -d $src/.opencode/command ] && mkdir -p $out/share/ponytail/commands && cp -r $src/.opencode/command/* $out/share/ponytail/commands/
  '';
}
```

## HM Options: `shared/ai-assets.nix`

```nix
{ config, lib, pkgs, ... }:
with lib;
{
  imports = [ ./opencode/mcps-base.nix ./opencode/mcps.nix ];

  options.home.ai-assets = {
    enable = mkEnableOption "Gentle AI ecosystem assets";

    skillSources = mkOption {
      type = types.listOf types.path;
      default = [
        "${pkgs.gentle-ai-assets}/share/gentle-ai/skills"
        "${pkgs.caveman-assets}/share/caveman/skills"
        "${pkgs.ponytail-assets}/share/ponytail/skills"
        "${pkgs.local-ai-assets}/share/local-ai/skills"
      ];
      description = "Ordered skill source directories (later wins on conflict).";
    };

    commandSources = mkOption {
      type = types.listOf types.str;  # path string — resolved at activation time
      default = [ ];  # set per-tool (opencode uses opencode/commands paths)
      description = "Ordered command source directories.";
    };

    agentsMdSources = mkOption {
      type = types.listOf types.path;
      default = [ "${pkgs.gentle-ai-assets}/share/gentle-ai/AGENTS.md" ];
      description = "Ordered AGENTS.md/CLAUDE.md fragments to concatenate.";
    };

    mcps = mkOption { /* unchanged from home.gentle-ai.mcps */ };
    extraMcps = mkOption { /* unchanged from home.gentle-ai.extraMcps */ };
    engramConfig = mkOption { type = types.attrsOf types.anything; default = {}; };
  };
}
```

`enable` is set by `opencode-profile.nix` and `claude-code-profile.nix` (both import `ai-assets.nix` and set `home.ai-assets.enable = true`).

## Activation Scripts (critical excerpts)

### Skills: N-way union + orphan cleanup across ALL sources
```bash
skills_target="$runtime_dir/skills"
mkdir -p "$skills_target"
sources_list="${lib.concatStringsSep " " config.home.ai-assets.skillSources}"
for src in $sources_list; do
  if [ -d "$src" ]; then
    (cd "$src" && ${pkgs.findutils}/bin/find . -type f) | while read -r rel; do
      if [ ! -f "$skills_target/$rel" ] || ! cmp -s "$src/$rel" "$skills_target/$rel"; then
        mkdir -p "$(dirname "$skills_target/$rel")"
        cp -f "$src/$rel" "$skills_target/$rel"; chmod 644 "$skills_target/$rel"
      fi
    done
  fi
done
# Orphan cleanup: delete files absent from ALL sources
(cd "$skills_target" && find . -type f) | while read -r rel; do
  found=0
  for src in $sources_list; do
    [ -f "$src/$rel" ] && { found=1; break; }
  done
  [ "$found" = "0" ] && rm -f "$skills_target/$rel"
done
```

### Commands: N-way union (same pattern as skills, using `commandSources`)

opencode.nix sets: `commandSources = [ "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/commands" "${pkgs.caveman-assets}/share/caveman/commands" "${pkgs.ponytail-assets}/share/ponytail/commands" ]`

claude-code.nix sets: `commandSources = [ "${pkgs.gentle-ai-assets}/share/gentle-ai/claude/commands" ]`

### AGENTS.md / CLAUDE.md: concat
```bash
# AGENTS.md: start fresh, cat each non-empty source
ag_md="${config.home.homeDirectory}/.config/opencode/AGENTS.md"
> "$ag_md"
for src in ${lib.concatStringsSep " " config.home.ai-assets.agentsMdSources}; do
  [ -f "$src" ] && [ -s "$src" ] && cat "$src" >> "$ag_md"
done
chmod 644 "$ag_md"
```
Claude Code's CLAUDE.md uses identical pattern, output to `~/.claude/CLAUDE.md`.

## File Reference Changes

| Reference | Old | New |
|-----------|-----|-----|
| review-gate.md (opencode) | `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/review-gate.md` | `./shared/opencode/assets/opencode/review-gate.md` |
| review-gate.md (claude) | `${pkgs.gentle-ai-assets}/share/gentle-ai/review-gate.md` | `./shared/opencode/assets/opencode/review-gate.md` |
| agents.nix sdd-overlay | `${pkgs.gentle-ai-assets-vanilla}` | `${pkgs.gentle-ai-assets}` |
| Import path | `./gentle-ai-common.nix` | `./ai-assets.nix` |
| Namespace | `config.home.gentle-ai` | `config.home.ai-assets` |

## Packages & Overlays

### `lib/packages.nix` changes
- **Remove**: `gentle-ai-assets-vanilla` definition (both linux and darwin)
- **Remove**: `sharedOpencodePaths` let-binding (extraAssets/extraFiles no longer needed)
- **Modify**: `gentle-ai-assets` now calls `../pkgs/gentle-ai-assets/default.nix` directly with `{ gentle-ai-src = inputs.gentle-ai-src; }` — no `vanilla`/`extraAssets`/`extraFiles` args
- **Add**: `caveman-assets` calling `../pkgs/caveman-assets { caveman-src = inputs.caveman-src; }`
- **Add**: `ponytail-assets` calling `../pkgs/ponytail-assets { ponytail-src = inputs.ponytail-src; }`

### Overlays
Remove `gentle-ai-assets-vanilla` from `inherit` list, add `caveman-assets`, `ponytail-assets` in both `overlays/linux.nix` and `overlays/darwin.nix`.

## Import Chain Verification

```
host default.nix
  → home-linux/shared-modules.nix
    → shared/opencode.nix       (imports: agents.nix, ai-assets.nix, permissions.nix, plugins.nix)
      → shared/ai-assets.nix    (imports: mcps-base.nix, mcps.nix)
    → shared/opencode-profile.nix (imports: ai-assets.nix; sets enable=true)
    → shared/claude-code.nix     (imports: ai-assets.nix)
    → shared/claude-code-profile.nix (imports: ai-assets.nix; sets enable=true)
```

No circular imports. All four modules import `ai-assets.nix` (was `gentle-ai-common.nix`). `ai-assets.nix` imports MCPs which reference `home.ai-assets.mcps` and `home.ai-assets.extraMcps`. `agents.nix` imports only `pkgs.gentle-ai-assets` — no circular dependency.

## File Changes Summary

| File | Action |
|------|--------|
| `pkgs/gentle-ai-assets/default.nix` | Rewrite (pure gentle-ai-src) |
| `pkgs/gentle-ai-assets/vanilla.nix` | Delete |
| `pkgs/caveman-assets/default.nix` | Create |
| `pkgs/ponytail-assets/default.nix` | Create |
| `shared/gentle-ai-common.nix` → `shared/ai-assets.nix` | Rename + rewrite |
| `shared/opencode.nix` | Modify (N-way loops, direct paths) |
| `shared/claude-code.nix` | Modify (N-way loops, direct paths, CLAUDE.md) |
| `shared/opencode-profile.nix` | Modify (import path, `home.ai-assets.enable`) |
| `shared/claude-code-profile.nix` | Modify (import path, `home.ai-assets.enable`) |
| `shared/opencode/agents.nix` | Modify (`pkgs.gentle-ai-assets-vanilla` → `pkgs.gentle-ai-assets`) |
| `shared/opencode/mcps-base.nix`, `mcps.nix` | Modify (namespace rename) |
| `home-darwin/opencode/mcps-extra.nix` | Modify (namespace rename) |
| `lib/packages.nix` | Modify (add caveman/ponytail, remove vanilla + sharedOpencodePaths) |
| `overlays/linux.nix`, `overlays/darwin.nix` | Modify (add/remove package names) |
| `shared/assets/review-gate.md` | Delete |
| `shared/opencode/assets/skills/` | Delete (empty dir + .gitkeep) |
| `docs/gentle-ai-update.md` | Modify |

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | Each derivation produces expected output | `nix build` each new pkg; verify `$out/share/` structure |
| Build | Full host configs build | `nix build .#nixosConfigurations.{rog,t14,thinkcentre,mact2}.config.system.build.toplevel` |
| Eval | `nix flake check --no-build` | Zero errors |
| Activation | Skills union deploys all skills | Check `~/.config/opencode/skills/` contains gentle-ai + caveman + ponytail + local skills |
| Activation | AGENTS.md / CLAUDE.md concat | Verify both files exist and contain upstream content |
| Activation | Orphan cleanup | Remove a skill from source, rebuild, verify it's deleted from target |
| Cleanup | No stale references | `grep -r 'gentle-ai-assets-vanilla\|home\.gentle-ai'` must return empty |

## Migration / Rollout

No migration required. This is a build-time refactor. Rollback: revert the 16 files and rebuild.

## Open Questions

None — the exploration and proposal fully resolved design questions.

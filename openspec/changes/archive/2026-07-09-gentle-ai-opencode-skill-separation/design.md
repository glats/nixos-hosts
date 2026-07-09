# Design: gentle-ai-opencode-skill-separation

## Technical Approach

Bring `sdd-review-policy.md` (115 lines, currently manual at `~/.config/opencode/`) into the existing three-stage Nix pipeline (`vanilla.nix` → `default.nix` extraAssets overlay → `opencode.nix` home.file + activation). Then document the upstream/local asset boundary in repo `AGENTS.md` and add a sed no-op warning. No new derivations, no flake inputs, no behavior change.

**Hosts affected**: all that import `shared/opencode.nix` via the home-manager shared module list — `rog`, `thinkcentre`, `t14` (linux) and `mact2` (darwin). All cross-platform.

## Architecture Decisions

| Decision | Choice | Alternatives | Rationale |
|----------|--------|--------------|-----------|
| Source file transport | extraAssets overlay (`shared/opencode/assets/opencode/`) | Dedicated home.file source in `shared/opencode/` | Mirrors existing `sdd-orchestrator.md` pattern; single transport mechanism for both root `opencode/` overrides |
| Boundary docs location | Repo `AGENTS.md` (new section) | `openspec/specs/gentle-ai-asset-overlay/spec.md` | Repo `AGENTS.md` is the agent-facing project doc; inventory belongs with structure docs, not nested in specs |
| Sed warning mechanism | `elif [ -f ... ]` branch emitting to stderr | Oneline `|| echo WARNING` after grep | File-missing and marker-missing are distinct conditions; `elif` covers marker-missing only (file-missing is expected on truncation windows) |

## Data Flow

```
~/.config/opencode/sdd-review-policy.md (manual, 115 lines)
  ↓  copy
shared/opencode/assets/opencode/sdd-review-policy.md  (new source)
  ↓  packages.nix:27  extraAssets = ./../shared/opencode/assets
  ↓  default.nix:68   cp -r ${extraAssets}/. $TEMP_DIR/
  ↓  default.nix:76   $out/share/gentle-ai/opencode/sdd-review-policy.md
  ↓  opencode.nix home.file  →  ~/.config/opencode/sdd-review-policy.md (symlink)
  ↓  activation loop (line 145)  →  real copy (read-only store → writable)
  ↓  ~/.config/opencode/sdd-review-policy.md (real file, Nix-managed)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `shared/opencode/assets/opencode/sdd-review-policy.md` | Create | Verbatim copy of `~/.config/opencode/sdd-review-policy.md` (115 lines) |
| `shared/opencode.nix` | Modify | +home.file entry (after line 102), +activation loop entry (line 145), +sed warning (lines 187-192) |
| `AGENTS.md` | Modify | New "Gentle AI Asset Boundary" section with inventory + policy/mechanism note |

### 1. Source file

Copy `~/.config/opencode/sdd-review-policy.md` verbatim to `shared/opencode/assets/opencode/sdd-review-policy.md`. The extraAssets mechanism (`default.nix:68`) copies the entire tree to nix store; the file flows to `$out/share/gentle-ai/opencode/sdd-review-policy.md` automatically.

### 2. opencode.nix home.file entry

Insert after line 102 (the `sdd-orchestrator.md` block), before the `# skills/` comment:

```nix
        ".config/${runtimeCfg.dir}/sdd-review-policy.md" = {
          force = true;
          source = "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/sdd-review-policy.md";
        };
```

### 3. opencode.nix activation loop entry

Line 145 — add `sdd-review-policy.md` to the `for file in` list:

**Before**:
```bash
for file in opencode.json IDENTITY.md AGENTS.md sdd-orchestrator.md instructions/universal.md package.json .gitignore tui.json; do
```

**After**:
```bash
for file in opencode.json IDENTITY.md AGENTS.md sdd-orchestrator.md sdd-review-policy.md instructions/universal.md package.json .gitignore tui.json; do
```

### 4. opencode.nix sed no-op warning

Lines 187-192 — add `elif` branch so a present file without the marker warns. Replaces silent no-op.

**Before** (lines 187-192):
```bash
for skill in sdd-apply sdd-verify; do
  skill_file="$runtime_dir/skills/$skill/SKILL.md"
  if [ -f "$skill_file" ] && head -1 "$skill_file" | grep -q '^<!-- section:model-capable -->$'; then
    ${pkgs.gnused}/bin/sed -i '1{/^<!-- section:model-capable -->$/d}' "$skill_file"
  fi
done
```

**After**:
```bash
for skill in sdd-apply sdd-verify; do
  skill_file="$runtime_dir/skills/$skill/SKILL.md"
  if [ -f "$skill_file" ] && head -1 "$skill_file" | grep -q '^<!-- section:model-capable -->$'; then
    ${pkgs.gnused}/bin/sed -i '1{/^<!-- section:model-capable -->$/d}' "$skill_file"
  elif [ -f "$skill_file" ]; then
    echo "WARNING: $skill model-capable marker not found on line 1 — upstream may have changed format" >&2
  fi
done
```

### 5. Boundary documentation (repo AGENTS.md)

Append a new section after "Owned Repos" (end of file, after line 127). Content:

```markdown
## Gentle AI Asset Boundary

Assets deployed to `~/.config/opencode/` come from three sources. Local overrides replace upstream assets; upstream changes auto-propagate on `nix flake update`.

| Asset | Origin | Transport |
|-------|--------|-----------|
| Skills (30) | Upstream gentle-ai + caveman | vanilla.nix → default.nix → opencode.nix activation |
| Skills (+2: nix-verify, opencode-session-recovery) | Local | extraSkills overlay (default.nix) |
| Commands (12) | Upstream gentle-ai | vanilla.nix → default.nix → opencode.nix activation |
| Agent overlay (18 agents) | Upstream sdd-overlay-single.json | agents.nix reads, merges local-agent-overlays.json |
| Agent tool/permission/instruction overlays | Local | local-agent-overlays.json + agents.nix `__replace__` merge |
| sdd-orchestrator.md (473 lines) | Mixed (upstream 431 + local 42) | extraAssets override (shared/opencode/assets/opencode/) |
| sdd-review-policy.md (115 lines) | Local | extraAssets override + opencode.nix home.file |
| IDENTITY.md, instructions/universal.md | Local | opencode.nix home.file |
| AGENTS.md | Upstream (vanilla) | opencode.nix home.file (symlink → real copy) |
| opencode.json | Generated | agents.nix + providers.nix → opencode.nix |

**Override mechanism**: `extraSkills` replaces entire skill directories; `extraAssets` copies a mirrored tree over vanilla, overwriting matching files; `agents.nix` merges upstream JSON + local overlay JSON via `__replace__` markers.

### Policy / Mechanism Pair

`sdd-review-policy.md` (WHAT/WHY: workflow diagram, iteration protocol, guard lines) and the `sdd-orchestrator.md` Review Gate section (HOW: artifact resolution, verdict table, binary decision) form a policy/mechanism pair. Both local; both Nix-managed after this change.
```

## Deployment Order

1. `home.file` creates symlink `~/.config/opencode/sdd-review-policy.md` → nix store.
2. `makeOpencodeConfigMutable` activation (runs AFTER `linkGeneration`) converts symlink → real copy via `cp --remove-destination`.
3. Orphan cleanup (skills/ and commands/ only) does NOT touch root-level files — no race, no deletion.

`home.file` always runs before activation (dag dependency `entryAfter [ "linkGeneration" ]`). No conflict.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Syntax | `nix flake check --no-build` | Must exit 0 for all hosts |
| Format | `format-nix` | No diff after formatting opencode.nix |
| Build | `nixos-build dry` on rog | Confirms derivation evaluates; new file present in nix store |
| Runtime | After rebuild: `file ~/.config/opencode/sdd-review-policy.md` | Must report "ASCII text" (real file), not symlink |
| Sed warning | Deploy without marker on line 1 (temp test) | Warning appears on stderr during activation |

## Migration / Rollout

No migration. On next `nixos-build`, the manual file is replaced by the Nix-managed real copy. To rollback: remove the home.file entry + activation loop entry, delete the source file, rebuild — manual placement is restored.

## Open Questions

- None. All mechanisms mirror existing `sdd-orchestrator.md` patterns.
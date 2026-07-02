# Design: omarchy-theme-set-kitty

## Technical Approach

Restore `omarchy-theme-set` runtime recoloring on t14 by changing `lib.mkForce` → `lib.mkDefault` on `programs.kitty.settings` in `home-linux/kitty.nix` (line 29). This allows omarchy-nix's `include` directive to merge into the final kitty config, enabling dynamic theme switching without rebuild.

The change leverages NixOS module system's `attrsOf` merge semantics: when both omarchy-nix and nixos-hosts define `settings` with `lib.mkDefault`, the attrsets merge key-by-key. Keys unique to each side survive; `background_opacity` is handled with `lib.mkForce "0.9"` to prevent equal-priority conflict with omarchy's `mkDefault "0.95"`.

## Architecture Decisions

### Decision: mkDefault over mkForce for settings

**Choice**: `lib.mkDefault` on `programs.kitty.settings`  
**Alternatives considered**: 
- Host-conditional `xdg.configFile` override on t14 only
- Keep `mkForce` and manually add `include` to nixos-hosts's attrset

**Rationale**: `mkDefault` is a one-line change with no host-conditional logic. It preserves the single-source-of-truth pattern while allowing omarchy-nix's runtime theme symlink to merge in. The manual `include` approach would hardcode a t14-specific path in a shared module, violating the consolidation principle.

### Decision: Accept natural merge for overlapping keys

**Choice**: No explicit priority overrides for `background_opacity`, `window_padding_width`, etc.  
**Alternatives considered**: 
- `lib.mkForce "0.6"` on `background_opacity` to guarantee nixos-hosts wins
- Remove `background_opacity` from nixos-hosts to let omarchy's "0.95" win

**Rationale**: The proposal explicitly accepts omarchy's values where they overlap (padding 10, keybindings). However, `background_opacity` requires an explicit `lib.mkForce "0.9"` to prevent equal-priority conflicts between omarchy's `mkDefault "0.95"` and nixos-hosts's `mkDefault` — the NixOS module system rejects equal-priority scalar conflicts in `attrsOf` rather than picking a winner. The `mkForce` ensures nixos-hosts's 0.9 always wins, consistent with the user's "0.9 for all hosts" preference.

### Decision: Defer ghostty to separate change

**Choice**: Only fix kitty in this change  
**Alternatives considered**: Fix both kitty and ghostty simultaneously

**Rationale**: Proposal explicitly scopes ghostty out. Same root cause (`mkForce` dropping `include`), but ghostty may have different merge semantics or user preferences. Separate change keeps review focused.

## Data Flow

```
t14 home-manager evaluation:
  1. omarchy-nix HM module imported first
     └─→ programs.kitty.settings = mkDefault {
           include = "~/.config/omarchy/current/theme/kitty.conf";
           background_opacity = "0.95";
           window_padding_width = 10;
           ...
         }
  
 2. nixos-hosts's home-linux/kitty.nix imported second
     └─→ programs.kitty.settings = mkDefault {
           background_opacity = lib.mkForce "0.9";
           scrollback_lines = -1;
           color0 = "#...";
           ...
         }

 3. Module system merges (attrsOf key-by-key)
     └─→ Final settings:
           include = "~/.config/omarchy/current/theme/kitty.conf"  ← from omarchy-nix
           background_opacity = "0.9"  ← from nixos-hosts (mkForce overrides mkDefault)
           window_padding_width = 10  ← same in both
           color0..color21 = "#..."  ← from nixos-hosts
           scrollback_lines = -1  ← from nixos-hosts

rog/thinkcentre evaluation:
  1. No omarchy-nix imported
  2. nixos-hosts's home-linux/kitty.nix
     └─→ programs.kitty.settings = mkDefault { ... }
  3. No merge competitor → mkDefault is effective priority
     └─→ Final settings: byte-identical to pre-change behavior
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `home-linux/kitty.nix` | Modify | Line 29: `settings = lib.mkForce {` → `settings = lib.mkDefault {` |
| `openspec/specs/kitty-consolidation/spec.md` | Modify | Relax "mkForce Override Pattern" requirement to allow `mkDefault`; document merge semantics for t14 vs rog/thinkcentre |

## Interfaces / Contracts

No new interfaces. The change modifies an existing NixOS module option's priority wrapper.

**Merge contract** (for `programs.kitty.settings` on t14):
- Keys unique to omarchy-nix (`include`) → survive
- Keys unique to nixos-hosts (colors, `scrollback_lines`, etc.) → survive
- `background_opacity` → nixos-hosts wins via `lib.mkForce "0.9"` (overrides omarchy's `mkDefault "0.95"`)
- Other keys in both (`window_padding_width`, `repaint_delay`, `input_delay`, `sync_to_monitor`) → same value in both, no conflict

**Keybindings contract**: omarchy-nix's `ctrl+insert` / `shift+insert` merge with nixos-hosts's `kitty_mod+f10` (different keys, no conflict).

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Evaluation | `nix flake check --no-build` passes | Run canonical validation command |
| Generated config | t14's `~/.config/kitty/kitty.conf` contains `include ~/.config/omarchy/current/theme/kitty.conf` | Build t14 HM config, inspect generated file |
| Regression | rog/thinkcentre kitty.conf byte-identical to pre-change | Build both HM configs, diff against baseline |
| Runtime | `omarchy-theme-set <theme>` changes kitty palette without rebuild | Run on t14, verify live recoloring |

## Migration / Rollout

No migration required. Single-line priority change, no data or state affected. Rollback: revert `mkDefault` → `mkForce` in `home-linux/kitty.nix` line 29.

## Open Questions

None. All questions from the proposal have been resolved:
- ✅ Ghostty deferred to separate change
- ✅ Opacity: nixos-hosts's `lib.mkForce "0.9"` wins on all hosts, overriding omarchy's `"0.95"` on t14
- ✅ Keybindings: accept natural merge (no conflict, different keys)

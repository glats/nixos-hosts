# Design: Unify Color System

## Technical Approach

Extract duplicated color helper functions (`hexToRgb`, `doubleHex`, `byteDoubleHex`) into `lib/colors.nix`, replace the local palette attrset in `kmscon.nix` with an import of `shared/palette.nix`, replace hardcoded hex values in `theme.nix` CSS with palette interpolation, and fix the Darwin ghostty `base04` -> `base03` drift. All consumers import from the shared library; zero local duplicates remain.

## Architecture Decisions

### Decision: `lib/colors.nix` receives `lib` as argument

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `{ lib }: { ... }` called with `import ../lib/colors.nix { inherit lib; }` | Explicit, no global coupling | Chosen |
| `{ pkgs, ... }: let lib = pkgs.lib; in { ... }` | Pulls in pkgs unnecessarily | Rejected |
| Inline in each consumer | Status quo duplication | Rejected |

**Rationale**: The `lib` set is already available in every NixOS/Home-Manager module. Passing it explicitly follows the existing `lib/packages.nix` pattern in this repo (import with `{ inherit ...; }`). No new dependencies introduced.

### Decision: `hexToRgb` returns bare `"r,g,b"` (no `rgb()` wrapper)

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Return `"r,g,b"` bare string | Flexible, consumer decides wrapping | Chosen |
| Return `"rgb(r,g,b)"` | Conflicts with kmscon which needs bare values | Rejected |
| Return attrset `{r;g;b;}` | Over-engineered for 3 call sites | Rejected |

**Rationale**: `kmscon.nix` needs `"r,g,b"` for `palette-*=` config lines. `mate.nix` currently wraps in `rgb(r,g,b)` for dconf, but can add the wrapper at the call site. Bare output satisfies both consumers.

### Decision: kmscon uses `let palette = import ../../shared/palette.nix;` (no `lib` arg needed)

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `import ../../shared/palette.nix` | palette.nix is a pure attrset, no args needed | Chosen |
| `import ../../shared/palette.nix { lib = lib; }` | Would require changing palette.nix signature | Rejected |

**Rationale**: `shared/palette.nix` is `{ slug = ...; ... }` - a plain attrset with zero parameters. Direct import works. No `config` access needed because kmscon is a NixOS module evaluated outside Home-Manager's `config.colorScheme`.

### Decision: CSS interpolation via `#${val}` in multiline string

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `#${config.colorScheme.palette.base02}` | Nix interpolates `base02` = `"505050"` -> `#505050` | Chosen |
| `builtins.replaceStrings` | Overly complex for simple replacement | Rejected |

**Rationale**: `gtk3.extraCss` is already a Nix multiline string literal. Interpolation of `config.colorScheme.palette.base02` yields `"505050"`, so `#${config.colorScheme.palette.base02}` produces `#505050` - valid CSS. No `replaceStrings` needed.

## Data Flow

```
shared/palette.nix ──────────────────────────────────────────────────┐
  (source of truth: base00-base0F, bright*)                             │
       │                                                                │
       ├─► home-linux/theme.nix                                        │
       │     config.colorScheme = import ../shared/palette.nix         │
       │     └─► gtk3.extraCss: #${config.colorScheme.palette.base02} │
       │                                                                │
       ├─► modules/desktop/kmscon.nix                                  │
       │     let palette = import ../../shared/palette.nix;            │
       │     └─► hexToRgb palette.palette.base00                       │
       │                                                                │
       ├─► home-linux/ghostty.nix                                      │
       │     config.colorScheme.palette.base03  (line 28)              │
       │                                                                │
       └─► home-darwin/ghostty.nix                                     │
            config.colorScheme.palette.base03  (line 25, was base04)   │
                                                                        │
lib/colors.nix ────────────────────────────────────────────────────────┤
  hexToRgb / doubleHex / byteDoubleHex                                │
       │                                                                │
       ├─► home-linux/mate.nix          (import ../lib/colors.nix)    │
       └─► modules/desktop/kmscon.nix   (import ../lib/colors.nix)    │
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/colors.nix` | Create | Shared color helper functions: `hexToRgb`, `doubleHex`, `byteDoubleHex` |
| `modules/desktop/kmscon.nix` | Modify | Remove local `p` and `hexToRgb`; import `shared/palette.nix` and `lib/colors.nix` |
| `home-linux/mate.nix` | Modify | Remove local `hexToRgb`, `doubleHex`, `byteDoubleHex`; import from `lib/colors.nix` |
| `home-linux/theme.nix` | Modify | Replace hardcoded `#505050` / `#ffffff` with `config.colorScheme.palette` interpolation |
| `home-darwin/ghostty.nix` | Modify | Change `base04` to `base03` on palette index 8 |

## Interfaces / Contracts

### `lib/colors.nix`

```nix
{ lib }:

let
  hexToRgb =
    hex:
    let
      r = lib.fromHexString (builtins.substring 0 2 hex);
      g = lib.fromHexString (builtins.substring 2 2 hex);
      b = lib.fromHexString (builtins.substring 4 2 hex);
    in
    "${toString r},${toString g},${toString b}";

  doubleHex =
    hex:
    lib.concatStrings (
      lib.concatMap
        (c: [ c c ])
        (lib.stringToCharacters hex)
    );

  byteDoubleHex =
    hex:
    let
      r = lib.substring 0 2 hex;
      g = lib.substring 2 2 hex;
      b = lib.substring 4 2 hex;
    in
    "${r}${r}${g}${g}${b}${b}";
in
{
  inherit hexToRgb doubleHex byteDoubleHex;
}
```

**Import pattern**: `let colors = import ../lib/colors.nix { inherit lib; };` then `colors.hexToRgb`, `colors.doubleHex`, `colors.byteDoubleHex`.

### `modules/desktop/kmscon.nix` (key excerpt)

```nix
{ pkgs, lib, ... }:

let
  palette = import ../../shared/palette.nix;
  colors = import ../lib/colors.nix { inherit lib; };
  p = palette.palette;
in
{
  services.kmscon = {
    # ...
    extraConfig = ''
      palette=custom
      palette-background=${colors.hexToRgb p.base00}
      # ... all entries use p.baseXX or p.brightXX
    '';
  };
}
```

**Note**: `p = palette.palette` flattens the nested import since `shared/palette.nix` returns `{ slug = ...; name = ...; palette = { base00 = ...; ...; }; }`. This avoids repeating `palette.palette` at every call site.

### `home-linux/theme.nix` (key CSS excerpt)

```nix
gtk3.extraCss = ''
  .caja-desktop.view .entry, .caja-navigation-window .view .entry {caret-color: white;}

  /* Fix: selected items invisible when window unfocused (backdrop state) */
  @define-color theme_unfocused_selected_bg_color #${config.colorScheme.palette.base02};
  @define-color theme_unfocused_selected_fg_color #${config.colorScheme.palette.base07};

  *:backdrop:selected {
    background-color: #${config.colorScheme.palette.base02} !important;
    color: #${config.colorScheme.palette.base07} !important;
  }

  .view:backdrop:selected {
    background-color: #${config.colorScheme.palette.base02} !important;
    color: #${config.colorScheme.palette.base07} !important;
  }

  row:backdrop:selected {
    background-color: #${config.colorScheme.palette.base02} !important;
    color: #${config.colorScheme.palette.base07} !important;
  }
'';
```

### `home-linux/mate.nix` (import change)

```nix
let
  colors = import ../lib/colors.nix { inherit lib; };
  hexToRgb = colors.hexToRgb;
  # hexToRgb injects bare "r,g,b" — mate/dconf needs rgb(r,g,b)
  # so we wrap it at the call site:
  #   "rgb(${hexToRgb config.colorScheme.palette.base00})"
  # instead of the old local version that returned "rgb(r,g,b)"
in
```

**Important**: The local `hexToRgb` in `mate.nix` currently returns `"rgb(r,g,b)"` (with wrapper). The shared version returns bare `"r,g,b"`. The call site at line 236 currently uses `${hexToRgb config.colorScheme.palette.base00}` which produced `rgb(0,0,0)`. After migration, it must become `rgb(${hexToRgb config.colorScheme.palette.base00})` to preserve the `rgb()` wrapper that dconf requires.

### `home-darwin/ghostty.nix` (line 25 change)

```nix
# Before: palette = 8=#${config.colorScheme.palette.base04}
# After:  palette = 8=#${config.colorScheme.palette.base03}
```

Single line change. All other lines remain identical to `home-linux/ghostty.nix`.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | `nix flake check` passes after all changes | CI-equivalent validation |
| Unit | `hexToRgb "0d73cc"` = `"13,115,204"` | Validate via `nix eval` or build check |
| Unit | `doubleHex "ab"` = `"aabb"` | Validate via `nix eval` or build check |
| Unit | `byteDoubleHex "cc0403"` = `"cccc04040303"` | Validate via `nix eval` or build check |
| Grep | No local `p = {` in `kmscon.nix` | `grep -n 'p = {' modules/desktop/kmscon.nix` |
| Grep | No local `hexToRgb` def in `mate.nix` | `grep -n 'hexToRgb' home-linux/mate.nix` shows import only |
| Grep | No `base04` in Darwin ghostty | `grep -n 'base04' home-darwin/ghostty.nix` returns nothing |
| Grep | No hardcoded `#505050` or `#ffffff` in `theme.nix` | `grep -n '505050\|ffffff' home-linux/theme.nix` shows only `${...}` interpolation |
| Format | All modified `.nix` files pass `nixfmt` | `format-nix` or `nix fmt` |

## Migration / Rollback

No migration required. All changes aredeclarative Nix config - a single `git revert` restores previous state. No data loss, no state migration.

Rollback: `git revert HEAD` (or the specific commit).

## Open Questions

None. All decisions are resolved from the spec and codebase analysis.
# Delta for color-system

No existing main specs. All requirements are new.

## ADDED Requirements

### Requirement: GTK CSS palette references

All hardcoded hex colors in `home-linux/theme.nix` `gtk3.extraCss` MUST reference `config.colorScheme.palette` via Nix string interpolation. No literal hex values matching palette entries SHALL remain.

Mapping (verified against `shared/palette.nix`): `#505050` -> `base02` (`"505050"`), `#ffffff` -> `base07` (`"ffffff"`).

#### Scenario: CSS uses palette interpolation

- GIVEN `base02 = "505050"` and `base07 = "ffffff"` in the palette
- WHEN `gtk3.extraCss` is evaluated
- THEN rendered CSS contains `#505050` and `#ffffff` from `${config.colorScheme.palette.*}` interpolation
- AND zero hardcoded `#505050` or `#ffffff` literals remain in Nix source

#### Scenario: Valid CSS output

- GIVEN interpolation uses `#${config.colorScheme.palette.base02}` syntax
- THEN each value appears as valid `#RRGGBB` in the final CSS

**Validation**: Grep Nix source for literal `#505050`/`#ffffff` returns zero matches. `nix flake check` passes.

---

### Requirement: kmscon palette deduplication

`modules/desktop/kmscon.nix` MUST import `shared/palette.nix` via `../../shared/palette.nix` and MUST NOT define a local `p` attrset or local `hexToRgb`. Color helpers MUST come from `lib/colors.nix`. kmscon is a NixOS module and cannot access `config.colorScheme.palette`.

#### Scenario: Shared palette import

- GIVEN `shared/palette.nix` exports `.palette` with `base00 = "000000"`, `base05 = "dddddd"`
- WHEN kmscon `extraConfig` evaluates
- THEN `palette-background` = `"0,0,0"` and `palette-foreground` = `"221,221,221"`

#### Scenario: Full base16 mapping

| kmscon key | Palette entry | Hex | RGB |
|---|---|---|---|
| background/black | base00 | `000000` | `0,0,0` |
| foreground/light-grey | base05 | `dddddd` | `221,221,221` |
| red | base08 | `cc0403` | `204,4,3` |
| green | base0B | `19cb00` | `25,203,0` |
| yellow | base0A | `cecb00` | `206,203,0` |
| blue | base0D | `0d73cc` | `13,115,204` |
| magenta | base0E | `cb1ed1` | `203,30,209` |
| cyan | base0C | `0dcdcd` | `13,205,205` |
| dark-grey | base03 | `8a8a8a` | `138,138,138` |
| light-red | base09 | `f2201f` | `242,32,31` |
| light-green | brightGreen | `23fd00` | `35,253,0` |
| light-yellow | brightYellow | `fffd00` | `255,253,0` |
| light-blue | brightBlue | `1a8fff` | `26,143,255` |
| light-magenta | brightMagenta | `fd28ff` | `253,40,255` |
| light-cyan | brightCyan | `14ffff` | `20,255,255` |
| white | base07 | `ffffff` | `255,255,255` |

**Validation**: Local `p` and `hexToRgb` absent from file. `nix flake check` passes.

---

### Requirement: Ghostty color8 cross-platform alignment

`home-darwin/ghostty.nix` palette index 8 MUST use `base03` (not `base04`). Both platforms SHALL produce identical palette assignments for all 16 indices.

#### Scenario: Darwin color8 matches Linux

- GIVEN Linux ghostty line 28: `8=#${config.colorScheme.palette.base03}`
- WHEN Darwin ghostty theme is evaluated
- THEN palette index 8 = `#8a8a8a` (base03)
- AND all 16 palette entries are identical between Linux and Darwin

**Validation**: Diff of effective palette values between hosts shows zero differences.

---

### Requirement: Shared color helpers library

`lib/colors.nix` MUST exist and export `hexToRgb`, `doubleHex`, `byteDoubleHex`. Both `home-linux/mate.nix` and `modules/desktop/kmscon.nix` MUST import from it and MUST NOT define these locally.

| Function | Input | Output | Example |
|---|---|---|---|
| `hexToRgb` | 6-char hex | `"r,g,b"` decimals | `"cc0403"` -> `"204,4,3"` |
| `doubleHex` | hex string | Each char doubled | `"ab"` -> `"aabb"` |
| `byteDoubleHex` | 6-char hex | Each byte pair doubled | `"cc0403"` -> `"cccc04040303"` |

`hexToRgb` MUST use `lib.fromHexString` for conversion.

#### Scenario: hexToRgb correctness

- GIVEN input `"0d73cc"` (base0D)
- THEN result is `"13,115,204"`

#### Scenario: doubleHex correctness

- GIVEN input `"ab"`
- THEN result is `"aabb"`

#### Scenario: byteDoubleHex correctness

- GIVEN input `"cc0403"` (base08)
- THEN result is `"cccc04040303"`

#### Scenario: Consumer migration

- GIVEN `lib/colors.nix` exports all three functions
- WHEN `mate.nix` and `kmscon.nix` are evaluated
- THEN local helper definitions are absent from both files
- AND output values are unchanged from current behavior

**Validation**: Grep for local function definitions in both consumers returns zero matches. `nix flake check` passes.

# Design: Fontconfig Rules via conf.d

## Architecture Decision

**Decision**: Write fontconfig rules directly to `/etc/fonts/conf.d/51-nixos-custom.conf` using `environment.etc` instead of `fonts.fontconfig.localConf`.

**Rationale**: The upstream NixOS fontconfig module generates `fonts.conf` via an XSLT that drops the `<include>local.conf</include>` directive. The generated `fonts.conf` only includes `/etc/fonts/conf.d/`. Therefore, any content written to `local.conf` is never loaded by fontconfig. Writing directly to conf.d bypasses this bug entirely because conf.d IS included.

---

## Priority Numbering Rationale

Priority 51 was chosen for the following reasons:

| Priority | Owner | Purpose |
|----------|-------|---------|
| 10 | NixOS module | Rendering config (antialias, hinting, subpixel) |
| **51** | **This change** | **Custom user rules (rejectfonts, redirects, strong aliases, emoji fallbacks)** |
| 52 | NixOS `defaultFonts` | Weak `binding="same"` aliases for generic families |
| 60 | fontconfig upstream | `60-latin.conf` — built-in Latin script weak aliases |

**Why 51 and not 50 or 53**:
- 51 loads AFTER rendering config (must have subpixel/hinting set first).
- 51 loads BEFORE `defaultFonts` (52) so custom strong aliases establish the preference baseline, then `defaultFonts` same-binding aliases append additional fonts. If the order were reversed, `defaultFonts` would be overridden by custom rules.
- 51 loads BEFORE fontconfig's 60-latin.conf, ensuring user's reject/redirect rules take precedence over built-in Latin fallbacks.
- 51 does not conflict with any NixOS-generated conf.d file (the module uses priorities 52 and up).

---

## XML Structure

The conf.d file is generated from the same XML generators currently in `modules/desktop/fonts.nix`. The structure (unchanged from current localConf):

```xml
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <!-- 1. REJECT: Liberation, DejaVu, Arimo, Tinos, Cousine -->
  <selectfont>
    <rejectfont>
      <pattern><patelt name="family"><string>Liberation Sans</string></patelt></pattern>
      <!-- ... 8 more families ... -->
    </rejectfont>
  </selectfont>

  <!-- 2. REDIRECT: Arial, Helvetica, etc. -> generic families -->
  <match target="pattern">
    <test name="family" qual="any"><string>Arial</string></test>
    <edit name="family" mode="assign" binding="same"><string>sans-serif</string></edit>
  </match>
  <!-- ... 11 more redirects ... -->

  <!-- 3. FORCE MATCH: monospace, mono -> Cascadia Code -->
  <match target="pattern">
    <test name="family" compare="eq"><string>monospace</string></test>
    <edit name="family" mode="assign" binding="same"><string>CaskaydiaCove Nerd Font</string></edit>
  </match>

  <!-- 4. STRONG ALIASES: family preferences -->
  <alias binding="strong">
    <family>sans-serif</family>
    <prefer>
      <family>Source Sans 3</family>
      <family>Noto Sans</family>
    </prefer>
  </alias>
  <alias binding="strong">
    <family>serif</family>
    <prefer>
      <family>Droid Serif</family>
      <family>Noto Serif</family>
    </prefer>
  </alias>
  <alias binding="strong">
    <family>monospace</family>
    <prefer>
      <family>CaskaydiaCove Nerd Font</family>
      <family>Noto Sans Mono</family>
    </prefer>
  </alias>

  <!-- 5. EMOJI FALLBACKS: weak accept aliases -->
  <alias binding="weak">
    <family>sans-serif</family>
    <accept>
      <family>JoyPixels</family>
      <family>Noto Color Emoji</family>
    </accept>
  </alias>
  <!-- ... for serif, monospace ... -->
</fontconfig>
```

---

## Integration with defaultFonts

The `defaultFonts` option in the NixOS fontconfig module generates `/etc/fonts/conf.d/52-nixos-default-fonts.conf` containing `binding="same"` aliases:

```xml
<alias binding="same">
  <family>sans-serif</family>
  <prefer><family>Source Sans 3</family><family>Noto Sans</family></prefer>
</alias>
```

With `binding="same"`, fontconfig merges multiple alias blocks for the same family at equal priority: `same` preferences are prepended, `weak` are appended. Since 51 (strong) runs before 52 (same), the final resolution order for "sans-serif" becomes:

```
Strong (51): Source Sans 3 > Noto Sans
Same (52):   Source Sans 3 (duplicate, deduped) > Noto Sans
Weak (60):   DejaVu Sans > Verdana > Arial > ...
```

Result: Source Sans 3 is first choice, Noto Sans is second, but DejaVu/Verdana/Arial can still enter if both primary fonts are unavailable. The `defaultFonts` is preserved unchanged — no duplication risk.

---

## Why environment.etc over localConf

| Property | localConf | environment.etc |
|----------|-----------|-----------------|
| Included in fonts.conf | No (XSLT drops it) | Yes (via conf.d directory scan) |
| Priority control | None (comment-only "indirect priority 51") | Explicit via filename prefix |
| Activation | NixOS activation script creates symlink | NixOS activation symlinks into /run/current-system |
| Rollback | Manual | Automatic via NixOS generation switching |
| Pattern precedent | None working in NixOS | Already used in `modules/hardware/nvidia.nix` |

`environment.etc` is the standard NixOS mechanism for placing files in `/etc`. It guarantees the file is symlinked from the immutable Nix store during activation and participates in generation rollback.

---

## Font Package Dependencies

| Font Family | Nix Package | Status | Notes |
|-------------|-------------|--------|-------|
| Source Sans 3 | `source-sans` | Already installed | pkgs.source-sans provides Source Sans 3 family |
| Cascadia Code Nerd Font | `nerd-fonts.caskaydia-cove` | Already installed | Full Nerd Font with extensive glyph support |
| Noto Serif | `noto-fonts` | Already installed | Includes Noto Serif (regular, bold, italic) |
| Noto Sans | `noto-fonts` | Already installed | Fallback sans-serif |
| Noto Sans Mono | `noto-fonts` | Already installed | Fallback monospace |
| JoyPixels | `joypixels` | Already installed | Emoji fallback |
| Noto Color Emoji | `noto-fonts` | Already installed | Emoji fallback |
| Symbola | `symbola` | Already installed | Symbol font |
| **Droid Serif** | **Not in nixpkgs** | **Unavailable** | No dedicated Droid font package exists in nixpkgs unstable. The `droid` package is LaTeX support only. Droid Serif will only be effective if the user installs it via `~/.local/share/fonts/`. The spec treats this as an opportunistic preference — if Droid Serif is present, it is preferred; otherwise fontconfig falls through to Noto Serif. |

**No new package dependencies are required.** All fonts except Droid Serif are already in the current `fonts.packages` list.

---

## Files Changed

| File | Change | Lines |
|------|--------|-------|
| `modules/desktop/fonts.nix` | Replace `localConf = "..."` block with `environment.etc."fonts/conf.d/51-nixos-custom.conf"`; update familyPrefs.serif to `["Droid Serif" "Noto Serif"]` | ~30 replaced, ~20 added |
| `hosts/t14/home/hypr/hyprlock.nix` | Line 54: `"Source Sans Pro"` -> `"Source Sans 3"` | 1 line |

## NixOS Options Used

| Option | Purpose |
|--------|---------|
| `environment.etc."fonts/conf.d/51-nixos-custom.conf".text` | Write XML conf to /etc via Nix store symlink |
| `fonts.fontconfig.defaultFonts.*` | Preserved unchanged — same-binding aliases at priority 52 |
| `fonts.packages` | Preserved unchanged — font package installation |
| `fonts.fontDir.enable` | Preserved unchanged |

## Rollback

Revert both files in git, rebuild. The old `localConf` mechanism (non-functional) is restored exactly. No state migration needed — conf.d files are store symlinks cleaned up by NixOS garbage collection.

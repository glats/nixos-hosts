# system-fontconfig Specification

## Purpose

System-wide fontconfig rules (rejectfonts, redirects, strong aliases, emoji fallbacks) deployed to `/etc/fonts/conf.d/` via `environment.etc`, replacing the broken `localConf` mechanism.

## Requirements

| # | Requirement | Strength | Validation |
|---|-------------|----------|------------|
| 1 | Deploy rules to `/etc/fonts/conf.d/51-nixos-custom.conf` | SHALL | `ls /etc/fonts/conf.d/51-nixos-custom.conf` exists post-rebuild |
| 2 | Reject Liberation, DejaVu, Arimo, Tinos, Cousine families | SHALL | `fc-list` excludes all nine families |
| 3 | Redirect Arial/Helvetica/etc. to generic families | SHALL | `fc-match Arial` resolves via sans-serif |
| 4 | Prefer Source Sans 3 (sans), Droid+Noto Serif (serif), Cascadia Code (mono) | SHALL | `fc-match sans-serif` returns Source Sans 3 first |
| 5 | Load at priority 51 (after rendering, before defaultFonts) | SHALL | 51 rules override 60-latin.conf, complement 52-defaultFonts |
| 6 | Apply to rog, thinkcentre, t14 (not mact2) | SHALL | `nix flake check --no-build` passes for all three Linux hosts |
| 7 | Fix hyprlock `"Source Sans Pro"` to `"Source Sans 3"` on t14 | SHALL | `grep "Source Sans 3" hosts/t14/home/hypr/hyprlock.nix` matches |

### Detailed Scenarios

#### Requirement 1: Conf.d Deployment

**Happy**: `nixos-rebuild switch` on any Linux host → `/etc/fonts/conf.d/51-nixos-custom.conf` is a valid XML symlink; `fc-cache -fv` processes it without errors.

**Edge**: Rebuild with identical config → file content unchanged across activations, no manual restore needed.

#### Requirement 2: Font Rejection

**Happy**: After rebuild, `fc-list | grep "DejaVu"` returns zero results. All nine rejected families are excluded from fontconfig's candidate pool.

**Edge**: App explicitly requests "Liberation Sans" → fontconfig rejects it silently and falls through to the next matching family in the alias chain.

#### Requirement 3: Font Name Redirection

**Happy**: `fc-match Arial` resolves to the sans-serif family with Source Sans 3 as first preference.

**Edge**: `fc-match "Times New Roman"` resolves to the serif family; `fc-match Courier` resolves to monospace.

#### Requirement 4: Font Family Preferences

**Happy**: `fc-match sans-serif` returns Source Sans 3 first; `fc-match monospace` returns "CaskaydiaCove Nerd Font" first.

**Edge-fold**: Source Sans 3 not installed → falls through to Noto Sans. Droid Serif not installed (not in nixpkgs) → falls through to Noto Serif.

#### Requirement 5: Priority Ordering

**Happy**: User's 51-level `<rejectfont>` blocks DejaVu even though 60-latin.conf lists it. The 51-level `<alias binding="strong">` establishes preference baseline before 52-level `defaultFonts`.

**Edge**: Fontconfig merges same-family aliases across priorities — strong (51) prepends, same (52) appends, weak (60) appends last. No conflicts.

#### Requirement 6: Cross-Host

**Happy**: `nix flake check --no-build` succeeds for rog, thinkcentre, and t14.

**Edge**: t14 disables HM fontconfig via `mkForce false` → relies exclusively on NixOS-level 51-nixos-custom.conf rules; no interference.

#### Requirement 7: Hyprlock Fix

**Happy**: `hosts/t14/home/hypr/hyprlock.nix` line 54 reads `font_family = lib.mkForce "Source Sans 3"`.

**Edge**: `fc-list | grep "Source Sans 3"` on t14 confirms font family recognized by fontconfig; hyprlock renders without fallback.

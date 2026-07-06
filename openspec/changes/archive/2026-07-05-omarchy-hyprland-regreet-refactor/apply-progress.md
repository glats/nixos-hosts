# Apply Progress: omarchy-hyprland-regreet-refactor

## Slice 1: Phase 1+2 (nixos-hosts low-risk cleanup)

| Field | Value |
|-------|-------|
| **Repo** | github.com/glats/nixos-hosts |
| **Branch** | master |
| **Commits** | 4 |
| **Lines** | +51 / -26 |

| SHA | Phase | Message |
|-----|-------|---------|
| `d12602d` | 1.1 | `fix(t14): remove obsolete WLR_RENDERER_ALLOW_SOFTWARE env var` |
| `cb54aa2` | 1.2 | `refactor(t14): gate full-opacity windowrule behind configurable boolean` |
| `4a39c65` | 2.1 | `refactor(t14): tighten waybar systemd restart limits` |
| `36848b9` | 2.2 | `docs(t14): document Hyprland-as-greeter-compositor architecture` |

## Slice 2: Phase 3 (omarchy-nix companion PR)

| Field | Value |
|-------|-------|
| **Repo** | github.com/glats/omarchy-nix |
| **PR** | https://github.com/glats/omarchy-nix/pull/6 |
| **Merge** | `e37c3d2` — squash-merged |

| Task | File | Change |
|------|------|--------|
| 3.1 | `modules/home-manager/hyprsunset.nix` | Raw config -> `services.hyprsunset` (44->15 lines) |
| 3.2 | `modules/nixos/system.nix` | `writeShellScript` -> `writeShellScriptBin`, 2s timeout, stderr logging |

## Slice 3: Phase 4+5 (nixos-hosts hyprsunset + integration)

| Field | Value |
|-------|-------|
| **Repo** | github.com/glats/nixos-hosts |
| **Branch** | master |
| **Commits** | 2 |
| **Lines** | +16 / -52 |

| SHA | Phase | Message |
|-----|-------|---------|
| `3a06d28` | 4.1 | `refactor(t14): migrate hyprsunset from raw config to services.hyprsunset` |
| `cfed91e` | 5.1 | `chore: bump omarchy-nix flake input for hyprsunset+greeter-script` |

## Verification Summary

| Check | Result |
|-------|--------|
| `nix flake check --no-build` (all hosts) | PASS |
| `nix build .#nixosConfigurations.t14.config.system.build.toplevel` | PASS |
| `nixos-build dry` | PASS (t14 only) |
| `grep -r WLR_RENDERER_ALLOW_SOFTWARE hosts/` | CLEAN |
| `grep -r "xdg.configFile.*hyprsunset" hosts/t14/` | CLEAN |
| 400-line budget | +67 / -78 (145 total, well under 400) |

## Pending (requires t14 hardware)

| Task | What |
|------|------|
| 5.2 | Greeter VT fallback test (`systemd.mask=greetd.service`) |
| 5.3 | Runtime: verify hyprsunset.conf generated via HM module |
# Design: restore-omarchy-hyprland-ownership

## Technical Approach

Upstream-first boundary refactor. `glats/omarchy-nix` becomes the single owner of Hyprland package selection; `hosts/t14/` becomes a config-only consumer.

1. **Upstream**: `modules/nixos/hyprland.nix` sets `programs.hyprland.package` and `programs.hyprland.portalPackage` to nixpkgs defaults (`pkgs.hyprland`, `pkgs.xdg-desktop-portal-hyprland`). `modules/home-manager/hyprland.nix` sets `wayland.windowManager.hyprland.package` and `portalPackage` to `lib.mkDefault null`, forcing HM to defer to the NixOS layer.
2. **Local**: After bumping `inputs.omarchy-nix` in `flake.nix`, delete the `programs.hyprland` force block in `hosts/t14/default.nix` and the `wayland.windowManager.hyprland` null-bridge in `hosts/t14/home/omarchy.nix`.

This maps directly to the proposal's Approach 3 (upstream-first, then downstream cleanup) and satisfies all spec requirements.

## Architecture Decisions

| Decision | Choice | Alternatives | Rationale |
|----------|--------|--------------|-----------|
| Package ownership boundary | NixOS module owns; HM defers via `mkDefault null` | HM owns; NixOS overrides | Hyprland upstream docs recommend NixOS-level ownership. Keeps one canonical layer. |
| Package source | nixpkgs `pkgs.hyprland` | omarchy flake-pinned Hyprland | Avoids Nix 2.34.x `${finalAttrs.src}/VERSION` eval bug during `nix flake check`. |
| HM deferral mechanism | `lib.mkDefault null` | Omit option entirely | Explicit `null` is clearer than omission and matches documented NixOS+HM integration pattern. |

## Data Flow

```
omarchy-nix NixOS module ──► programs.hyprland.{package,portalPackage}
         │                              │
         │                              ▼
omarchy-nix HM module ◄────── NixOS system profile
(mkDefault null on
 wayland.windowManager.hyprland.*)
         │
         ▼
hosts/t14/home/hypr/*.nix  (config-only, no package refs)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `glats/omarchy-nix:modules/nixos/hyprland.nix` | Modify | Adopt `pkgs.hyprland` / `pkgs.xdg-desktop-portal-hyprland` as default `package` / `portalPackage` |
| `glats/omarchy-nix:modules/home-manager/hyprland.nix` | Modify | Set `package = lib.mkDefault null; portalPackage = lib.mkDefault null;` |
| `flake.nix` | Modify | Bump `inputs.omarchy-nix` to commit carrying boundary fix |
| `hosts/t14/default.nix` | Modify | Remove `programs.hyprland` force block (lines 82–91) |
| `hosts/t14/home/omarchy.nix` | Modify | Remove `wayland.windowManager.hyprland` null-bridge (lines 102–112) |

## Interfaces / Contracts

No new interfaces. The existing `programs.hyprland` NixOS option and `wayland.windowManager.hyprland` HM option are used with standard `mkDefault` / `mkForce` priority semantics.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Evaluation | `nix flake check --no-build` | Must pass on `t14` config after cleanup |
| Build | `nixos-build dry` | Dry-run to confirm no eval errors or missing packages |
| Runtime | Hyprland session launch | Manual smoke test after `nixos-rebuild switch` on t14 |

## Migration / Rollout

No migration required. This is a pure ownership refactor with no user-facing behavior change.

## Open Questions

None blocking design. Upstream questions (e.g., whether to expose `omarchy.hyprland.package` option) are out of scope for the local change and do not affect the `hosts/t14/` cleanup.

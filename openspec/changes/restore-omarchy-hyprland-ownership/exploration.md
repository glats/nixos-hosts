## Exploration: restore-omarchy-hyprland-ownership

### Current State
`t14` currently imports `inputs.omarchy-nix.nixosModules.default` from `flake.nix` and `inputs.omarchy-nix.homeManagerModules.default` from `hosts/t14/home/omarchy.nix`. The local repo is carrying the Hyprland ownership bridge in two places: `hosts/t14/default.nix` force-sets `programs.hyprland.package = pkgs.hyprland` and `programs.hyprland.portalPackage = pkgs.xdg-desktop-portal-hyprland`, while `hosts/t14/home/omarchy.nix` force-sets `wayland.windowManager.hyprland.package = null` and `portalPackage = null`.

The locked upstream input confirms why this exists. `flake.lock` pins `omarchy-nix` to `b90134b93676a2474f6d5e1bb11e8e02e8a31ca6`, and that upstream revision still duplicates ownership:
- `modules/nixos/hyprland.nix` sets `programs.hyprland.package` and `portalPackage` from `inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}`.
- `modules/home-manager/hyprland.nix` also sets `wayland.windowManager.hyprland.package` from the same Hyprland flake input instead of deferring to NixOS.

The local `hosts/t14/home/hypr/*.nix` files are already consumer-only. They set Hyprland settings, extraConfig, and xdph config, but no package-ownership attributes.

### Affected Areas
- `flake.nix` — owns the `omarchy-nix` input and is the activation gate for an upstream boundary fix.
- `flake.lock` — currently pins `omarchy-nix` to `b90134b93676a2474f6d5e1bb11e8e02e8a31ca6`, which still has split ownership upstream.
- `hosts/t14/default.nix` — contains the local NixOS-side Hyprland provider override.
- `hosts/t14/home/omarchy.nix` — contains the local Home Manager null-defer bridge.
- `hosts/t14/home/default.nix` — imports the `home/hypr/*.nix` config fragments and shows the intended config-only consumer layer.
- `hosts/t14/home/hypr/*.nix` — already config-only; should remain untouched by ownership logic.
- `glats/omarchy-nix:modules/nixos/hyprland.nix` — upstream provider module that should be sole owner of package/provider selection.
- `glats/omarchy-nix:modules/home-manager/hyprland.nix` — upstream HM module that should defer package ownership instead of duplicating it.

### Approaches
1. **Keep the current local scattered bridge** — leave the `mkForce` package override in `hosts/t14/default.nix` and the HM null bridge in `hosts/t14/home/omarchy.nix`.
   - Pros: No upstream wait; current intent is already documented locally.
   - Cons: Violates the desired provider/consumer boundary; spreads ownership policy across host and HM files; easy to regress on next `omarchy-nix` bump.
   - Effort: Low

2. **Temporary local boundary module** — move all four ownership attributes into one temporary `hosts/t14/hyprland-boundary.nix` and delete the scattered overrides.
   - Pros: Better local clarity if upstream is delayed; keeps `hosts/t14/home/hypr/*.nix` clean; creates one removable bridge.
   - Cons: Still leaves this repo owning upstream policy; adds temporary local surface area that must be deleted after the bump.
   - Effort: Medium

3. **Upstream-first ownership fix** — update `omarchy-nix` so its NixOS module is the only owner of `programs.hyprland.{package,portalPackage}`, and its HM module uses the documented defer pattern (`package = null; portalPackage = null`, ideally with `lib.mkDefault`) so HM stays config-only with respect to package ownership.
   - Pros: Matches the requested architecture; keeps this flake consumer-only; removes the need for local bridges after bumping `inputs.omarchy-nix`; aligns with Hyprland community guidance.
   - Cons: Depends on upstream PR/merge timing; ownership cleanup alone does not guarantee `nix flake check --no-build` is fully green if separate local store-path issues still exist.
   - Effort: Medium

### Recommendation
Use **Approach 3** as the main path. The real issue is not just null-vs-package mechanics; it is that `omarchy-nix` currently owns Hyprland twice. The clean contract is: upstream `omarchy-nix` NixOS module owns the provider, upstream `omarchy-nix` HM module defers, and this repo only consumes/configures Hyprland behavior. After that upstream fix exists, bump `inputs.omarchy-nix` in `flake.nix` and delete the local ownership bridge from `hosts/t14/default.nix` and `hosts/t14/home/omarchy.nix`.

If the upstream PR is delayed, use exactly one temporary local boundary module as fallback. Do not keep the current scattered override pattern.

### Risks
- Upstream dependency risk: local cleanup should not happen before the `omarchy-nix` boundary fix is available and pinned.
- Verification scope risk: even after ownership cleanup, `nix flake check --no-build` may still expose unrelated local invalid store-path issues.
- Upstream behavior risk: `omarchy-nix` currently pins `hyprwm/Hyprland/v0.54.3`; changing provider ownership may also need upstream agreement on whether nixpkgs Hyprland is now the default source.

### Ready for Proposal
Yes — proposal/apply work should be framed as: upstream `omarchy-nix` first, local input bump second, local bridge deletion third, with a single temporary local boundary module only if upstream timing blocks immediate cleanup.

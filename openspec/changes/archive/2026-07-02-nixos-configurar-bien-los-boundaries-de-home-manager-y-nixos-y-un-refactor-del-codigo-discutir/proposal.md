# Proposal: Linux Home Manager Composition Alignment

**Change**: nixos configurar bien los boundaries de home-manager y nixos y un refactor del codigo. discutir
**Phase**: propose
**Date**: 2026-07-02
**Status**: draft

---

## Intent

Unify the Linux Home Manager composition path so that the standalone
`homeConfigurations` entries in `flake.nix` and the NixOS-integrated HM path
share a single authoritative source of truth: the per-host
`hosts/<host>/home/modules.nix` files.

Today, two independent composition paths exist for the same hosts. They diverge
silently. The standalone path is incomplete relative to the integrated path, so
`home-manager switch` and `nixos-rebuild switch` do not produce the same user
environment. That is a correctness bug, not just an aesthetic disagreement.

---

## Problem Statement

### The Divergence

`modules/base/home-manager.nix` imports:

```
hosts/${config.networking.hostName}/home/modules.nix
```

`flake.nix` standalone `homeConfigurations.rog` imports:

```
linuxHomeModules ++ [ ./home-linux/conky-rog.nix ./home-linux/openfang.nix ]
```

`hosts/rog/home/modules.nix` imports:

```
shared-modules ++ [
  remote-desktop.nix
  picom.nix
  mate-rog-autostart.nix
  conky-rog.nix
  openfang.nix
  webcam-rog.nix
  shell-gpt.nix
  { home.shell-gpt.enable = true; }
]
```

The file also contains a commented-out host-specific OpenCode provider override,
but it is inactive and therefore not part of the current divergence.

The standalone path silently drops `remote-desktop`, `picom`,
`mate-rog-autostart`, `webcam-rog`, `shell-gpt`, and the active inline
`home.shell-gpt.enable = true` override. A user running
`home-manager switch --flake .#rog` gets a
materially different environment than after `nixos-rebuild switch`.

`thinkcentre` has the same structural leak: standalone imports
`linuxHomeModules + [conky-thinkcentre]`; the integrated path imports
`shared-modules + [remote-desktop, picom, conky-thinkcentre, shell-gpt]`.

### Why This Is Worth Fixing Now

- The divergence is repo-local and does not require upstream coordination.
- The fix has a clear, mechanical shape: replace ad-hoc extra-module lists with
  calls to the per-host HM files that already exist.
- It creates one obvious place to add new per-host HM configuration going
  forward.

---

## Scope

### In Scope

1. Rewrite `flake.nix` `homeConfigurations.rog` to derive its module list from
   `hosts/rog/home/modules.nix`.
2. Rewrite `flake.nix` `homeConfigurations.thinkcentre` to derive its module
   list from `hosts/thinkcentre/home/modules.nix`.
3. Remove the `linuxHomeModules` prepend from the standalone path for `rog` and
   `thinkcentre` (it will be handled inside each host's `modules.nix`, which
   already imports `shared-modules.nix`).
4. Update the comment block in `flake.nix` near `mkHomeConfig` and
   `linuxHomeModules` to reflect the new ownership model.

### Out of Scope

- `t14` / Omarchy standalone path — kept as-is. The `t14` standalone entry in
  `flake.nix` is already structurally different for valid reasons (Omarchy HM
  module, no `linuxHomeModules` prepend, explicit `omarchy.*` injection). It
  is explicitly preserved as a documented special case.
- `mact2` Darwin standalone path — not affected.
- Removing `mkForce` overrides in `hosts/t14/home/omarchy.nix`.
- Omarchy upstreaming or provider/consumer contract changes.
- `home-linux/ghostty.nix`, `home-linux/kitty.nix`, `home-linux/git.nix`
  compatibility shim cleanup.
- Font/theme layer ownership documentation.
- Introducing new module options or named roles.

---

## Affected Files

| File | Change |
|------|--------|
| `flake.nix` | Replace `baseHomeConfig "rog" ...` and `baseHomeConfig "thinkcentre" ...` bodies so they import the per-host `modules.nix` instead of appending to `linuxHomeModules`. Update surrounding comments. |
| `hosts/rog/home/modules.nix` | No change required — already the authoritative source. |
| `hosts/thinkcentre/home/modules.nix` | No change required — already the authoritative source. |
| `home-linux/shared-modules.nix` | No change required — remains the shared base imported by both host files. |
| `modules/base/home-manager.nix` | No change required — already uses `hosts/.../home/modules.nix`. |

No other files are expected to change under this proposal.

---

## Proposed Approach

### Option Selected: Approach 1 from Exploration

Normalize the standalone Linux HM path around the per-host import files.

### Implementation Shape

Replace in `flake.nix` (inside `homeConfigurations`):

```nix
# Before
rog = baseHomeConfig "rog" "x86_64-linux" "glats" [
  ./home-linux/conky-rog.nix
  ./home-linux/openfang.nix
];
thinkcentre = baseHomeConfig "thinkcentre" "x86_64-linux" "glats" [
  ./home-linux/conky-thinkcentre.nix
];
```

```nix
# After
rog = home-manager.lib.homeManagerConfiguration {
  pkgs = pkgsFor "x86_64-linux";
  modules = import ./hosts/rog/home/modules.nix { inherit inputs; };
  extraSpecialArgs = {
    inherit inputs;
    hostName = "rog";
    username = "glats";
  };
};
thinkcentre = home-manager.lib.homeManagerConfiguration {
  pkgs = pkgsFor "x86_64-linux";
  modules = import ./hosts/thinkcentre/home/modules.nix { inherit inputs; };
  extraSpecialArgs = {
    inherit inputs;
    hostName = "thinkcentre";
    username = "glats";
  };
};
```

`mkHomeConfig` / `baseHomeConfig` remain available for Darwin. After this
change, no active Linux standalone entry needs that wrapper.

`linuxHomeModules` becomes an unused let-binding in `flake.nix` after this
change. Removing that dead binding is intentionally out of scope to keep this
slice focused on the composition-correctness fix.

---

## Rationale

The per-host `modules.nix` files were created precisely as the ownership
boundary for host-specific HM composition. The integrated NixOS path already
uses them correctly. Making the standalone path do the same removes the only
source of duplication and makes both paths provably equivalent.

This is the "Approach 1" recommendation from the exploration phase and is
endorsed by the exploration analysis as the strongest near-term move.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Standalone path gains new modules that change the current standalone environment | Medium | Low | This is the intended behavior of the fix: align standalone HM with the already-existing integrated HM path. Validate with explicit standalone HM builds before apply. |
| A newly included module could require NixOS-only context unavailable in standalone HM | Low | Medium | This has already been spot-checked for `remote-desktop.nix`, `picom.nix`, `mate-rog-autostart.nix`, `conky-rog.nix`, `conky-thinkcentre.nix`, `openfang.nix`, `webcam-rog.nix`, and `shell-gpt.nix`; keep explicit `activationPackage` builds as the final proof. |
| `shell-gpt.enable = true` in `rog` modules.nix propagates to standalone. | Low | Low | Desired — consistent with NixOS-integrated path. |
| Review budget for this PR is tight (primary change is `flake.nix`, 30–50 lines). | Low | Low | Single-file delta keeps review focused. |

### Rollback Plan

The change is limited to `flake.nix`. If the standalone paths break:

1. Revert the `flake.nix` `homeConfigurations` block to the previous
   `baseHomeConfig` calls (one commit revert is sufficient).
2. The NixOS-integrated path (`nixos-rebuild switch`) is unaffected and
   continues to work regardless of this change.

No NixOS modules, no hardware config, no secrets, and no host files are
modified. Rollback has zero risk to running systems.

---

## Dependencies

- `hosts/rog/home/modules.nix` must continue to exist and be importable as
  a function `{ inputs } -> [ modules ]`. It already satisfies this contract.
- `hosts/thinkcentre/home/modules.nix` — same.
- `modules/base/home-manager.nix` passes `conkyConfig = config.conky-config` as
  `extraSpecialArgs`, but `conky-rog.nix` and `conky-thinkcentre.nix` define
  their own local `conkyConfig` value and do not consume any top-level
  `conkyConfig` argument. No standalone fallback is required.

---

## Success Criteria

1. `nix flake check --no-build` passes for the repo-level flake outputs and
   registered NixOS checks after the change.
2. `nix build .#homeConfigurations.rog.activationPackage` succeeds with no
   evaluation errors.
3. `nix build .#homeConfigurations.thinkcentre.activationPackage` succeeds with
   no evaluation errors.
4. The module lists in `homeConfigurations.rog` and `homeConfigurations.thinkcentre`
   are provably derived from their per-host `modules.nix` files (readable from
   `flake.nix` without cross-referencing a second list).
5. `homeConfigurations.t14` and `homeConfigurations.mact2` are unchanged.

---

## Change Shape: Bounded or Initiative?

This is a **bounded, single-PR change**.

- Primary file: `flake.nix`
- Secondary: no additional file changes are expected.
- Expected review size: under 60 lines changed.
- No NixOS module changes, no host default.nix changes, no new files.

---

## Follow-Up Work (Out of Scope Here)

These are explicitly deferred and should become separate proposals:

1. **Document the NixOS/HM boundary contract** — a short spec that defines
   which concerns belong to NixOS, which to HM, and when cross-layer coupling
   (`osConfig`) is acceptable.
2. **`t14` / Omarchy provider-consumer cleanup** — delete `mkForce` bridges
   in `hosts/t14/home/omarchy.nix` by upstreaming option surface into
   `glats/omarchy-nix`. Multi-repo work, separate change stream.
3. **Shared HM compatibility-shim cleanup** — revisit `home-linux/ghostty.nix`,
   `home-linux/kitty.nix`, `home-linux/git.nix` after Omarchy ownership is
   clarified.
4. **Font/theme boundary documentation** — define which font and theme settings
   belong to NixOS (`modules/desktop/fonts.nix`) versus HM (`omarchy.fonts.*`,
   GTK), and replace comment-based rules with option-level enforcement.

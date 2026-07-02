## Exploration: nixos configurar bien los boundaries de home-manager y nixos y un refactor del codigo. discutir

### Current State

This repo already has a recognizable high-level split:

- **NixOS owns machine and system state**: host imports, boot, users, PAM, services, fonts, networking, packages, desktop/session services, hardware, and secrets bootstrap. The main path is `flake.nix` -> `lib/mkHost.nix` -> `hosts/<host>/default.nix` -> `modules/**`.
- **Home Manager owns user environment state**: shells, terminals, dotfiles, desktop entries, user services, app config, `home.packages`, and user secret consumers. The main Linux path is `modules/base/home-manager.nix` -> `hosts/<host>/home/modules.nix` -> `home-linux/**` and `shared/**`.

That boundary is cleanest on `rog` and `thinkcentre` at the top level: their host files stay mostly NixOS-only, while HM ownership is delegated to `hosts/rog/home/modules.nix` and `hosts/thinkcentre/home/modules.nix`.

However, three important leaks remain:

1. **Standalone Linux HM is not using the same ownership boundary as integrated HM.**
   - `modules/base/home-manager.nix` imports `hosts/${config.networking.hostName}/home/modules.nix`.
   - `flake.nix` standalone `homeConfigurations.rog` / `thinkcentre` do not reuse those files; they build from `linuxHomeModules` plus a small extra list.
   - Result: integrated HM and standalone HM are not the same composition surface.

2. **`t14` bypasses the shared Linux HM composition entirely.**
   - `hosts/t14/default.nix` does not import `modules/base/home-manager.nix`.
   - It defines its own `home-manager` block inline and points directly to `./home/omarchy.nix`.
   - This is intentional because `t14` is a curated Omarchy consumer, but it means the repo currently has two different HM boundary models for Linux hosts.

3. **Some ownership is still resolved by override combat instead of a stable provider/consumer contract.**
   - `hosts/t14/home/omarchy.nix` contains many `lib.mkForce` overrides against upstream `omarchy-nix` HM defaults (`programs.zsh.zplug`, `programs.starship`, `fonts.fontconfig.enable`, `services.hypridle.settings`, `gtk.iconTheme`, `gtk.colorScheme`, etc.).
   - `home-linux/ghostty.nix`, `home-linux/kitty.nix`, and `home-linux/git.nix` explicitly document that they are overriding upstream Omarchy behavior.
   - This is evidence that the layer boundary exists conceptually, but not yet as a stable ownership contract.

### Affected Areas

- `flake.nix`
  - Defines `linuxHomeModules` and standalone `homeConfigurations`.
  - Repeats Linux HM composition differently from the NixOS-integrated path.
- `lib/mkHost.nix`
  - Wires the NixOS Home Manager module globally for Linux hosts.
- `modules/base/home-manager.nix`
  - The canonical integrated Linux HM bridge.
  - Delegates per-host HM imports to `hosts/<host>/home/modules.nix`.
- `hosts/rog/home/modules.nix`, `hosts/thinkcentre/home/modules.nix`
  - Good examples of explicit per-host HM ownership.
- `hosts/t14/default.nix`, `hosts/t14/home/omarchy.nix`, `hosts/t14/home/default.nix`
  - The largest mixed-boundary area.
  - NixOS host state, HM state, and upstream-override policy all meet here.
- `home-linux/shared-modules.nix`
  - Shared Linux HM base list.
  - Clean as a shared list, but not the only real composition source because standalone Linux uses a different append pattern.
- `home-linux/*`
  - Mostly correct HM-layer files.
  - A few are “shared HM modules that exist partly to neutralize upstream HM behavior” rather than just declaring user config.
- `modules/base/sops.nix` vs `shared/sops.nix`
  - A clean example of the intended split: NixOS owns host bootstrap secrets; HM owns user secret consumption.
- `modules/desktop/fonts.nix` vs `hosts/t14/home/omarchy.nix`
  - Shows a real cross-layer tension: system font availability is NixOS-owned, but HM-level `fonts.fontconfig.enable` and per-app font choices are user-layer concerns.

### Concrete Boundary Findings

#### 1. Current boundary between NixOS and Home Manager

The practical boundary in this repo is:

- **NixOS layer**
  - `users.users.*`
  - `environment.systemPackages`
  - `services.*`
  - `networking.*`
  - `boot.*`
  - `fonts.packages` and system `fonts.fontconfig`
  - PAM/keyring/session bootstrap
  - hardware and initrd settings
  - host secrets and machine identity

- **Home Manager layer**
  - `home.packages`
  - `programs.*` for user applications and shell tools
  - `xdg.configFile`, `xdg.dataFile`, `home.file`
  - `home.activation`
  - `systemd.user.services`
  - user-level theming and desktop app behavior
  - user-side secret references via HM sops module

This matches Home Manager documentation: HM integrates through `home-manager.users.<name>` under the NixOS module tree, while still remaining a separate module namespace for user environment configuration.

#### 2. Most obvious leaks or misplaced ownership decisions

1. **Linux standalone HM composition drift**
   - Biggest structural leak.
   - Two sources of truth exist for Linux HM composition: `hosts/*/home/modules.nix` for integrated HM, and `flake.nix` lists for standalone HM.
   - This is the clearest refactor target because it is repo-local and not conceptually ambiguous.

2. **`t14` has a second HM architecture**
   - `rog`/`thinkcentre`: HM composition is owned by per-host HM files.
   - `t14`: HM composition is owned inline in `hosts/t14/default.nix` and `hosts/t14/home/omarchy.nix` because Omarchy needs curated imports.
   - This may be justified, but it should be treated as an explicit special architecture, not an accidental variation.

3. **Upstream Omarchy ownership is still contested locally**
   - Repeated `mkForce` in `hosts/t14/home/omarchy.nix` indicates local user preferences are overriding upstream defaults at scale.
   - This is a classic provider/consumer leak: local host config is carrying policy that probably belongs in upstream option surface.

4. **Some shared HM modules are actually compatibility shims against Omarchy**
   - `home-linux/ghostty.nix` fully replaces Omarchy Ghostty settings.
   - `home-linux/kitty.nix` selectively wins conflicts against Omarchy Kitty.
   - `home-linux/git.nix` forces identity over Omarchy-derived identity.
   - These files are valid HM files, but they reveal that “shared nixos-hosts HM defaults” and “Omarchy defaults” have not been fully reconciled.

5. **Visual/font ownership is split across layers and not always named clearly**
   - `modules/desktop/fonts.nix` intentionally owns system-wide font installation and system fontconfig.
   - `hosts/t14/home/omarchy.nix` disables HM fontconfig and then uses HM/app-level font overrides through `omarchy.fonts.*` and GTK settings.
   - This can be correct, but the repo still relies on comments and `mkForce` rather than a small documented contract for which font concerns belong to NixOS vs HM.

#### 3. Places that look correct and should be preserved

1. **Per-host HM import files for `rog` and `thinkcentre`**
   - `hosts/rog/home/modules.nix`
   - `hosts/thinkcentre/home/modules.nix`
   - These are strong boundaries: host owns import selection; shared modules stay reusable.

2. **System sops vs user sops split**
   - `modules/base/sops.nix` for machine/bootstrap secrets.
   - `shared/sops.nix` for HM/user consumers.

3. **NixOS modules for services and HM modules for user tooling**
   - Example: `modules/features/services/xrdp.nix` owns system XRDP/MATE plumbing.
   - `home-linux/remote-desktop.nix` owns Remmina profiles, launchers, and user-side client behavior.

### Approaches

| Approach | Pros | Cons | Effort |
|---|---|---|---|
| 1. Normalize Linux HM composition around per-host HM import files | Fixes the clearest local boundary leak; makes integrated and standalone Linux HM share one source of truth; low conceptual risk | Does not solve `t14`/Omarchy ownership conflicts by itself | Medium |
| 2. Explicitly classify `t14` as a curated special-case architecture | Honest model; avoids forcing `t14` into `rog`/`thinkcentre` shape; keeps Omarchy path intentional | Preserves repo complexity; still leaves many override-based contracts | Low/Medium |
| 3. Push more Omarchy-facing ownership upstream and shrink local overrides | Best long-term provider/consumer boundary; removes many `mkForce` fights; aligns with prior Omarchy refactors | Multi-repo work; depends on upstream `omarchy-nix`; too large for one proposal if mixed with local composition cleanup | High |
| 4. Introduce explicit repo-local boundary rules/options for shared desktop roles | Could replace implicit assumptions with named roles/capabilities; good for future hosts | Adds option surface and indirection; may be heavier than needed for 4 hosts | Medium/High |
| 5. Full boundary refactor as one umbrella change | One narrative, comprehensive cleanup | Too large; mixes separable risks (local HM composition, Omarchy upstreaming, font/theme contracts, t14 special handling) | High |

### Tradeoff Discussion

#### Approach 1: Normalize Linux HM composition first

This is the strongest near-term move.

Recommended direction:

- Make `flake.nix` standalone Linux HM entries reuse `hosts/<host>/home/modules.nix`, not ad-hoc extra module lists.
- Preserve `home-linux/shared-modules.nix` as the shared base, but treat host HM files as the only composition owners.

Why this is attractive:

- It fixes a real bug-shaped boundary leak.
- It is local to this repo.
- It reduces surprise immediately.
- It does not require resolving the entire Omarchy contract first.

#### Approach 2: Keep `t14` intentionally special

This is plausible and probably necessary.

The repo already has two Linux families:

- XRDP/MATE hosts (`rog`, `thinkcentre`)
- Omarchy/Hyprland host (`t14`)

Trying to erase that difference completely may create artificial abstractions. A better direction is:

- normalize composition rules where possible,
- but document `t14` as a curated consumer path with stricter upstream dependency.

#### Approach 3: Continue the Omarchy upstreaming campaign

This repo has prior art for this exact pattern.

The evidence in current code suggests several `t14` local overrides are not really “host-only facts”; they are user-policy defaults that should move upstream into Omarchy option surface. Examples:

- `services.hypridle.settings`
- `gtk.iconTheme` and dark-mode glue
- some Hyprland look-and-feel preferences
- some terminal/theme ownership conflicts

This is likely a separate change stream from the Linux HM composition cleanup.

### Is this one change or several separable changes?

It is likely **several separable changes**, not one safe implementation change.

Recommended split:

1. **Linux HM composition alignment**
   - Unify standalone and integrated Linux HM composition.
   - Keep scope strictly repo-local.

2. **Document and tighten the NixOS/HM boundary contract**
   - Small design/proposal change.
   - Define what belongs in NixOS, what belongs in HM, and when cross-layer coupling is allowed.

3. **`t14` / Omarchy ownership cleanup**
   - Separate change, likely multi-step and possibly multi-repo.
   - Focus on deleting `mkForce` bridges by upstreaming option surface.

4. **Optional follow-on simplification of shared HM modules**
   - Revisit `home-linux/ghostty.nix`, `home-linux/kitty.nix`, `home-linux/git.nix`, maybe `tmux`-style modules, after Omarchy ownership is clarified.

Trying to do all of this in one proposal would likely exceed a safe review budget and mix independent decisions.

### Recommendation

The proposal should be scoped as a **staged boundary refactor**, not a single broad “refactor the boundaries” change.

Recommended planning scope for the next proposal:

#### Proposal scope: Phase 1 only

Target only the strongest repo-local problem:

- Make Linux standalone HM composition derive from the same per-host HM ownership files used by the NixOS-integrated path.
- Preserve `t14` special handling for now.
- Do not mix in Omarchy upstreaming yet.

That proposal can still mention future follow-ons:

- `t14`/Omarchy provider-consumer cleanup
- shared HM compatibility-shim cleanup
- documenting font/theme boundary rules

#### Why this scope is best

- Concrete and easy to verify.
- Solves a real ownership inconsistency immediately.
- Keeps review size controlled.
- Avoids mixing local refactor work with upstream Omarchy negotiations.

### Risks

- **False unification risk**: forcing `t14` into the same HM composition model as `rog`/`thinkcentre` may hide legitimate architectural differences.
- **Multi-repo creep**: once Omarchy override cleanup is included, the work becomes upstream-dependent and much larger.
- **Hidden behavior drift**: standalone HM and integrated HM may already diverge in ways users rely on; composition alignment should be treated as behavior-sensitive even if the intent is “just refactor”.
- **Override-removal risk**: some `mkForce` blocks in `t14` are carrying real behavior, not dead code. They should not be collapsed without upstream replacements.

### External Research Notes

- Home Manager docs confirm the NixOS integration model: HM is added as `home-manager.nixosModules.home-manager`, and user config lives under `home-manager.users.<name>` while remaining its own module namespace.
- Current Nix community guidance also supports keeping NixOS and HM in the same repo while avoiding mixed ownership inside the same module. NixOS should own system settings; HM should consume system state through `osConfig` when necessary rather than making user config the source of system truth.

### Ready for Proposal

Yes.

But the recommended proposal should be **narrow**:

- **In scope**: unify Linux HM composition ownership between integrated and standalone paths.
- **Out of scope**: full `t14`/Omarchy cleanup, broad theme/font contract redesign, and upstream module changes.
- **Follow-up proposal likely needed**: `t14` provider/consumer cleanup against `omarchy-nix`.

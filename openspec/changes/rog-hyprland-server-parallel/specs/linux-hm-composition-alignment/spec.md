# Delta for linux-hm-composition-alignment

## ADDED Requirements

### Requirement: HM-SA-07 -- rog backward-compat wrapper re-exports omarchy.nix import list

`hosts/rog/home/modules.nix` MUST be a backward-compat wrapper that re-exports the exact same import list as `hosts/rog/home/omarchy.nix`. The canonical HM entry point for rog is `omarchy.nix`. The wrapper file MUST include a deprecation comment directing future consumers to use `./omarchy.nix` instead.

The re-exported list SHALL be identical to the `imports` attribute of `omarchy.nix`:
- `inputs.omarchy-nix.homeManagerModules.default` (first, t14 pattern)
- `./default.nix` (rog-specific Hyprland overlays)
- Individual `home-linux/` modules: `base.nix`, `shell.nix`, `tmux.nix`, `neovim.nix`, `git.nix`, `gh.nix`, `ssh.nix`, `remote-desktop.nix`, `ghostty.nix`, `kitty.nix`, `alacritty.nix`, `shell-gpt.nix`, `openfang.nix`, `webcam-rog.nix`
- Individual `shared/` modules: `shell-aliases.nix`, `opencode.nix`, `opencode-profile.nix`, `sops.nix`
- `inputs.sops-nix.homeManagerModules.sops`
- `({ home.shell-gpt.enable = true; })`

#### Scenario: modules.nix re-exports identically to omarchy.nix

- GIVEN `hosts/rog/home/modules.nix` is a backward-compat wrapper
- WHEN the file is evaluated with `{ inputs }`
- THEN it returns a list identical to the `imports` attribute of `hosts/rog/home/omarchy.nix`
- AND the first element is `inputs.omarchy-nix.homeManagerModules.default`
- AND the second element is `./default.nix`
- AND every module in the list matches a corresponding entry in `omarchy.nix`'s imports
- AND it does NOT import `../../../home-linux/shared-modules.nix`

#### Scenario: both standalone and integrated paths use omarchy.nix directly

- GIVEN `flake.nix` standalone path imports `./hosts/rog/home/omarchy.nix`
- AND `hosts/rog/default.nix` HM path also imports `./home/omarchy.nix`
- WHEN both `homeConfigurations.rog` and `nixosConfigurations.rog` are evaluated
- THEN both resolve the same omarchy-compatible module set
- AND the HM-SA-01 single-source guarantee is preserved (both paths use the same canonical file)
- AND `modules.nix` is preserved only for any stale references (backward compat)

#### Scenario: omarchy HM module resolves in standalone build

- GIVEN `omarchy.nix` imports `inputs.omarchy-nix.homeManagerModules.default`
- WHEN `nix build .#homeConfigurations.rog.activationPackage` is run
- THEN the omarchy-nix HM module resolves without missing-inputs errors
- AND no MATE/X11 module conflicts occur (mate, rofi, conky are absent)

## MODIFIED Requirements

### Requirement: HM-SA-02 -- Standalone and integrated module lists are provably equivalent

After this change, for `rog` and `thinkcentre`, the set of HM modules evaluated by `home-manager switch --flake .#<host>` MUST be identical to the set evaluated by `nixos-rebuild switch`, with the only permitted exceptions being modules that explicitly require NixOS context (`osConfig`) and are listed in a documented exception registry (see HM-SA-05).

The equivalence guarantee remains -- both paths derive from the same canonical source. For rog, the canonical source is `hosts/rog/home/omarchy.nix` (not `modules.nix`, which exists only as a backward-compat re-export). Thinkcentre is unaffected.

(Previously: rog's `modules.nix` was the active shared source wrapping `shared-modules.nix` + MATE/X11 additions. Now `omarchy.nix` is the canonical source; `modules.nix` is a backward-compat re-export.)

#### Scenario: rog standalone module set matches integrated module set

- GIVEN `hosts/rog/home/omarchy.nix` is the canonical shared source
- WHEN `homeConfigurations.rog` and `nixosConfigurations.rog` are both evaluated
- THEN the resolved module list for `homeConfigurations.rog` includes every module that `nixosConfigurations.rog` evaluates through its HM path: `omarchy-nix.homeManagerModules.default` + `base.nix` + `shell.nix` + `tmux.nix` + `neovim.nix` + `git.nix` + `gh.nix` + `ssh.nix` + `remote-desktop.nix` + `opencode.nix` + `opencode-profile.nix` + `sops.nix` + `shell-aliases.nix` + `shell-gpt.nix` + `fontconfig.nix` + `{ home.shell-gpt.enable = true; }`
- AND `mate.nix`, `rofi.nix`, `chrome-apps.nix`, `theme.nix` are NOT present (documented per HM-SA-07)
- AND no module present in the integrated path is absent from the standalone path (unless in the exception registry per HM-SA-05)

#### Scenario: rog omarchy modules are present, MATE modules are absent

- GIVEN `omarchy.nix` is the canonical HM entry point for rog
- WHEN `nix build .#homeConfigurations.rog.activationPackage` is run
- THEN the build includes Hyprland-related config from `omarchy-nix.homeManagerModules.default`
- AND `dconf.settings` from `home-linux/mate.nix` is NOT evaluated
- AND `programs.rofi` options are NOT available (excluded by HM-SA-07)
- AND `programs.google-chrome` policy from `chrome-apps.nix` is NOT set

#### Scenario: thinkcentre standalone module set matches integrated module set

- GIVEN `hosts/thinkcentre/home/modules.nix` is the shared source
- WHEN `homeConfigurations.thinkcentre` and `nixosConfigurations.thinkcentre` are both evaluated
- THEN the resolved module list for `homeConfigurations.thinkcentre` includes every module that `nixosConfigurations.thinkcentre` evaluates through its HM path: `shared-modules` + `remote-desktop.nix` + `picom.nix` + `conky-thinkcentre.nix` + `shell-gpt.nix`
- AND no module present in the integrated path is absent from the standalone path (unless in the exception registry per HM-SA-05)

#### Scenario: Previously missing modules are now present in thinkcentre standalone

- GIVEN the old `flake.nix` standalone path only appended `conky-thinkcentre.nix`
- WHEN the change is applied and `nix build .#homeConfigurations.thinkcentre.activationPackage` is run
- THEN the build includes `remmina`, `libsecret`, and Remmina profiles (from `remote-desktop.nix`)
- AND `services.picom.enable` is set to `true` (from `picom.nix`)

## Unchanged

HM-SA-01, HM-SA-03, HM-SA-04, HM-SA-05, HM-SA-06 are unaffected. Rog uses `hosts/rog/home/omarchy.nix` as the single source (HM-SA-01); `modules.nix` is a backward-compat re-export. `extraSpecialArgs` requirements unchanged (HM-SA-03). t14 remains a documented special case (HM-SA-04). No new exceptions required (HM-SA-05). Flake check must still pass (HM-SA-06).

# Delta for linux-hm-composition-alignment

## ADDED Requirements

### Requirement: HM-SA-07 -- rog HM diverges from shared-modules.nix for omarchy compatibility

Rog's `hosts/rog/home/modules.nix` MUST import an omarchy-compatible HM module subset instead of `shared-modules.nix`. The omarchy-nix HM module SHALL be imported first (t14 pattern). The following shared modules MUST be excluded: `mate.nix`, `rofi.nix`, `chrome-apps.nix`, `theme.nix`. The divergence SHALL be documented in `modules.nix` with an inline comment explaining the exclusion rationale (same convention as `hosts/t14/home/omarchy.nix` lines 17-25).

| Action | Modules |
|--------|---------|
| Include | `inputs.omarchy-nix.homeManagerModules.default` |
| Include | `home-linux/{base,shell,tmux,neovim,git,gh,ssh}.nix` |
| Include | `home-linux/{remote-desktop,shell-gpt,fontconfig}.nix` |
| Include | `shared/{opencode,opencode-profile,sops,shell-aliases}.nix` |
| Include | `inputs.sops-nix.homeManagerModules.sops` |
| Exclude | `home-linux/{mate,rofi,chrome-apps}.nix`, `home-linux/theme.nix` |
| Exclude | `home-linux/{mate-rog-autostart,conky-rog,openfang,webcam-rog,picom,kitty,alacritty,gpg,ghostty}.nix` -- MATE/X11-specific or duplicative with omarchy |

#### Scenario: rog modules.nix imports omarchy-compatible subset

- GIVEN `hosts/rog/home/modules.nix` is the shared source
- WHEN the file is read
- THEN it imports `inputs.omarchy-nix.homeManagerModules.default` first
- AND it imports the individual shared modules listed in the Include table above
- AND it does NOT import `../../../home-linux/shared-modules.nix`
- AND it does NOT import `mate.nix`, `rofi.nix`, `chrome-apps.nix`, or `theme.nix`

#### Scenario: both standalone and integrated paths use new modules.nix

- GIVEN `flake.nix` standalone path imports `./hosts/rog/home/modules.nix`
- AND `modules/base/home-manager.nix` imports `../../hosts/rog/home/modules.nix`
- WHEN both `homeConfigurations.rog` and `nixosConfigurations.rog` are evaluated
- THEN both resolve the same omarchy-compatible module set
- AND the HM-SA-01 single-source guarantee is preserved (both paths unchanged)

#### Scenario: omarchy HM module resolves in standalone build

- GIVEN `modules.nix` imports `inputs.omarchy-nix.homeManagerModules.default`
- WHEN `nix build .#homeConfigurations.rog.activationPackage` is run
- THEN the omarchy-nix HM module resolves without missing-inputs errors
- AND no MATE/X11 module conflicts occur (mate, rofi, conky are absent)

## MODIFIED Requirements

### Requirement: HM-SA-02 -- Standalone and integrated module lists are provably equivalent

After this change, for `rog` and `thinkcentre`, the set of HM modules evaluated by `home-manager switch --flake .#<host>` MUST be identical to the set evaluated by `nixos-rebuild switch`, with the only permitted exceptions being modules that explicitly require NixOS context (`osConfig`) and are listed in a documented exception registry (see HM-SA-05).

The equivalence guarantee remains -- both paths derive from the same `hosts/<host>/home/modules.nix` source. Rog's module set has changed from `shared-modules.nix`-based to omarchy-compatible (documented in HM-SA-07), but the single-source mechanism (HM-SA-01) is unchanged. Thinkcentre is unaffected.

(Previously: rog's module set was `shared-modules.nix` + MATE/X11 host-specific additions. Now it is omarchy-compatible, excluding mate/rofi/chrome-apps/theme.)

#### Scenario: rog standalone module set matches integrated module set

- GIVEN `hosts/rog/home/modules.nix` is the shared source (omarchy-compatible subset)
- WHEN `homeConfigurations.rog` and `nixosConfigurations.rog` are both evaluated
- THEN the resolved module list for `homeConfigurations.rog` includes every module that `nixosConfigurations.rog` evaluates through its HM path: `omarchy-nix.homeManagerModules.default` + `base.nix` + `shell.nix` + `tmux.nix` + `neovim.nix` + `git.nix` + `gh.nix` + `ssh.nix` + `remote-desktop.nix` + `opencode.nix` + `opencode-profile.nix` + `sops.nix` + `shell-aliases.nix` + `shell-gpt.nix` + `fontconfig.nix` + `{ home.shell-gpt.enable = true; }`
- AND `mate.nix`, `rofi.nix`, `chrome-apps.nix`, `theme.nix` are NOT present (documented per HM-SA-07)
- AND no module present in the integrated path is absent from the standalone path (unless in the exception registry per HM-SA-05)

#### Scenario: rog omarchy modules are present, MATE modules are absent

- GIVEN the new `modules.nix` imports omarchy-compatible subset
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

HM-SA-01, HM-SA-03, HM-SA-04, HM-SA-05, HM-SA-06 are unaffected. Rog still uses `hosts/rog/home/modules.nix` as the single source (HM-SA-01). `extraSpecialArgs` requirements unchanged (HM-SA-03). t14 remains a documented special case (HM-SA-04). No new exceptions required (HM-SA-05). Flake check must still pass (HM-SA-06).

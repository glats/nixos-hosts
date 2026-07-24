# Tasks: HM Suites Organization

## Task 1: Move files + fix paths

- [ ] `mkdir -p linux/home/suites/mate linux/home/suites/mate-rog`
- [ ] `git mv` these 5 files:
  - `mate.nix` → `suites/mate/mate.nix`
  - `rofi.nix` → `suites/mate/rofi.nix`
  - `picom.nix` → `suites/mate/picom.nix`
  - `chrome-apps.nix` → `suites/mate/chrome-apps.nix`
  - `mate-rog-autostart.nix` → `suites/mate-rog/default.nix`
- [ ] Fix `suites/mate/mate.nix`: `../../lib` → `../../../lib`
- [ ] Fix `suites/mate/chrome-apps.nix`: `./chrome-app-icons` → `../../chrome-app-icons`

## Task 2: Create aggregator

- [ ] Create `linux/home/suites/mate/default.nix`:
  ```nix
  [
    ./mate.nix
    ./rofi.nix
    ./picom.nix
    ./chrome-apps.nix
  ]
  ```

## Task 3: Update imports

- [ ] `shared-modules.nix`: remove `./mate.nix`, `./rofi.nix`, `./chrome-apps.nix`
- [ ] `hosts/rog/home/default.nix`: replace `mate-rog-autostart.nix` with `suites/mate` + `suites/mate-rog`
- [ ] `hosts/thinkcentre/home/default.nix`: add `suites/mate`

## Task 4: Verify

- [ ] `format-nix`
- [ ] `nix flake check --no-build`
- [ ] `nix build .#nixosConfigurations.rog.config.system.build.toplevel`
- [ ] `nix build .#nixosConfigurations.thinkcentre.config.system.build.toplevel`

---

Decision needed before apply: No
Chained PRs recommended: No
400-line budget risk: Low
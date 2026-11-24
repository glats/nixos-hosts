# NixOS Multi-Host Configuration

## Repository Facts

- Hosts: `rog` (MATE, XRDP, NVIDIA, home server), `thinkcentre` (headless, XRDP), `t14` (ThinkPad, Omarchy/Hyprland), `samsung` (Samsung tablet PC, GNOME), and `macm5` (Apple Silicon, nix-darwin).
- Users: `glats` on Linux; `juan` on `macm5` (work GitHub identity is SOPS-managed).
- Stack: NixOS flakes, Home Manager (integrated and standalone), sops-nix, and nix-darwin.
- `/etc/nixos` is a symlink to this repository (`~/.nixos`).
- `hosts/<host>/default.nix` is each host entry point; host imports are flat and explicit, one per line.
- Linux modules live in `linux/system/` and `linux/home/`; Darwin modules live in `darwin/`; cross-platform Home Manager modules live in `shared/`.
- `linux/home/shared-modules.nix` and `darwin/home/shared-modules.nix` are the canonical shared Home Manager module lists.
- Overlays in `overlays/` are imported by flake builders, never used as modules.
- Custom operational binaries live in `pkgs/nixos-scripts/`; `bin/webcam` is the only shell-script exception.
- Secrets are sops-encrypted under `secrets/`; `.sops.yaml` defines creation-rule ordering.

## Omarchy and t14

- `flake.nix` pins `github:glats/omarchy-nix` at commit `5fc93f4c86f4766e477b7e94776e4a7c25ed3579`.
- Only `t14` receives `inputs.omarchy-nix.nixosModules.default` and `inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen4` through `extraModules`.
- `hosts/t14/home/omarchy.nix` imports `inputs.omarchy-nix.homeManagerModules.default`; `hosts/t14/home/default.nix` imports that entry point.
- The Linux shared module list includes the `btop` Home Manager module. `omarchy-runtime` and `quickshell` reach `t14` through the `omarchy-nix` and `t14-quickshell` inputs: the omarchy modules read them from the flake inputs directly, so no local overlay is involved.

## ROMHarbor and rog

- ROMHarbor is the separate community application at `https://github.com/glats/romharbor`; its canonical local checkout is `~/Project/romharbor`.
- Keep the orchestration session in the current NixOS worktree. A related application checkout is not a request to move this session; preserve isolated application worktrees and read their own `AGENTS.md` before edits.
- Keep ongoing application worktrees and their Git metadata in permanent directories anchored to the canonical repository. Temporary directories are for disposable build/test scratch, not the only copy of unfinished work.
- ROMHarbor owns application code, command/query handlers, tests, its standalone flake/module, and container/release packaging. This repository owns host selection, storage, domains, authentication, version pins and deployment.
- Integrate the application as a pinned external flake input, like Omarchy-nix, rather than embedding application source in `pkgs/nixos-scripts`. The `romharbor` input pins the verified v0.1.5 application for `rog`; activation and the running-service cutover are user-owned.
- Keep private configuration out of the community repository. Do not remove the legacy source or change the running service before a verified replacement and coordinated cutover.

## Commands and Verification

- `nixos-build` selects the local platform and host; use `safe`, `dry`, `boot`, `test`, `upgrade`, or `check` for the corresponding operation.
- Format touched Nix files with `nix fmt -- <path>`.
- Evaluate host-scoped changes with `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`, `nix eval .#homeConfigurations.<host>.activationPackage.drvPath`, or `nix eval .#darwinConfigurations.<host>.config.system.build.toplevel.drvPath`.
- Lint: run `nix build .#checks.x86_64-linux.lint` (or `nix flake check`, or `nixos-build check`) before calling a change done, and fix every new finding; never silence a rule. It runs `statix`, `deadnix`, `gofmt -l` and `go vet`. Existing Nix findings are recorded in `lint/baseline.txt`: never add to the baseline, and remove entries only after a cleanup. When the same mistake recurs, propose a new rule under `lint/` with a passing and a failing fixture and wait for approval; do not add rules on your own.
- Shared changes require `nix flake check --no-build`; it does not evaluate Darwin or standalone Home Manager configurations, so evaluate those targets separately.
- Test Go operational binaries with `go -C pkgs/nixos-scripts test ./...`; deployment uses the Nix-built `nixos-scripts` derivation.
- Run supported commands directly; RTK rewrites supported commands automatically. Use `git status -sb` when ahead/behind state matters.

## Critical Rules

- Never edit `hardware-configuration.nix`; it is generated.
- New NixOS modules belong under `linux/system/<category>/` and are imported directly by the host. `linux/system/features/` has no `default.nix`.
- New portable services belong under `linux/system/services/<category>/`; new Home Manager modules belong in the platform directory or `shared/` and must be registered in the matching shared module list.
- Operational command-line tools are Go, not shell scripts. Keep entry points thin under `pkgs/nixos-scripts/cmd/` and shared logic under `pkgs/nixos-scripts/internal/`.
- Never decrypt sops secrets. Add specific `.sops.yaml` creation rules before generic host rules.
- Unfree packages are globally enabled; license-gated packages also need host-level allow-list and acceptance settings.
- nixpkgs is pinned to `nixos-26.05`; nix-darwin uses the matching `nix-darwin-26.05` branch.
- Repository code, comments, documentation, runbooks, and CLI messages are written in English.

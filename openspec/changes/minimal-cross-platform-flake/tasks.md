# Tasks: Minimal Cross-Platform Flake

## Review Workload Forecast

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Low

Estimate ~140–160 changed lines (5 small Nix files + 2 docs); far under the 400-line budget.
Threat matrix: N/A per design (no routing/shell/VCS/PR automation boundaries) — no RED-test tasks.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|---|---|---|---|---|---|
| 1 | Repo, flake, hosts, home module | PR 1 | `nix flake check --no-build` | selector evals (7.3–7.4) | delete `/home/glats/minimal-nix` |
| 2 | Install docs | PR 1 | guard greps (7.5) | install-day manual runbook (Linux/macOS first boots) | delete the two docs |

## Phase 1: Foundation — Repo Bootstrap

- [x] 1.1 Create and initialize `/home/glats/minimal-nix`: `git init /home/glats/minimal-nix`. Verify remote-free: `git -C /home/glats/minimal-nix remote -v` prints nothing.
- [x] 1.2 Create directories `hosts/minimal-linux/`, `hosts/minimal-mac/`, `home/`.

## Phase 2: Core — Shared Home Manager Module

- [x] 2.1 Create `home/shared.nix` containing exactly `{ pkgs, ... }: { home.packages = [ pkgs.codex ]; }` — Codex is the only package; no auth content (no `~/.codex/config.toml` write, no `OPENAI_API_KEY`, no `home.activation`) anywhere.

## Phase 3: Core — Linux Host (`hosts/minimal-linux/configuration.nix`)

- [x] 3.1 Boot/networking/SSH: `boot.loader.systemd-boot.enable = true;`, `boot.loader.efi.canTouchEfiVariables = true;`, `networking.hostName = "minimal-linux";`, `networking.useNetworkd = true;` + `systemd.network.enable = true;` with catch-all DHCP (`networks."40-all"`, `matchConfig.Name = "*"`, `DHCP = "yes"`), `services.openssh.enable = true;`.
- [x] 3.2 User: `users.users.claudio = { isNormalUser = true; extraGroups = [ "wheel" ]; initialHashedPassword = (run mkpasswd -m sha-512 and paste its output here); };` — user is `claudio`, never anything else; the password hash is generated fresh during apply by the user running `mkpasswd -m sha-512` and pasted into the file (never copied from any existing account's hash or cleartext).
- [x] 3.3 Console: `services.kmscon = { enable = true; hwRender = false; useXkbConfig = true; }` (attr shape validated against `linux/system/desktop/kmscon.nix` (read-only)); leave `term` at default `xterm-256color`; no `COLORTERM` anywhere in this repo.
- [x] 3.4 Eval-safe hardware handoff + stateVersion: `system.stateVersion = "26.05";` and `imports = lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;` — pick up the user-generated file only after install-time generation; never create/modify it (Hard Boundary).

## Phase 4: Core — macOS Host (`hosts/minimal-mac/configuration.nix`)

- [x] 4.1 `system.stateVersion = 5;` and `users.users.claudio = { home = "/Users/claudio"; shell = "/bin/zsh"; uid = 501; };` (spec: home `/Users/claudio`, a UID, a shell).
- [x] 4.2 Integrated HM: `home-manager.useUserPackages = true;` and `home-manager.users.claudio = { imports = [ ../../home/shared.nix ]; home.username = "claudio"; home.homeDirectory = "/Users/claudio"; home.stateVersion = "25.05"; };` (`"25.05"` is the proven value for HM master on nixpkgs-26.05: `darwin/home/default.nix:31` (read-only)).

## Phase 5: Core — Flake Wiring (`flake.nix`)
- [x] 5.1 Inputs: `nixpkgs = github:NixOS/nixpkgs/nixos-26.05`; `nix-darwin = github:nix-darwin/nix-darwin/nix-darwin-26.05`; `home-manager = github:nix-community/home-manager/master`; `determinate = https://flakehub.com/f/DeterminateSystems/determinate/3`; each non-nixpkgs input sets `inputs.nixpkgs.follows = "nixpkgs"`. No sops-nix/agenix/omarchy inputs.
- [x] 5.2 Outputs: `nixosConfigurations.minimal-linux = inputs.nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = [ inputs.home-manager.nixosModules.default ./hosts/minimal-linux/configuration.nix ]; };`. No standalone `homeConfigurations` (per flake-bootstrap spec: not required).
- [x] 5.3 `darwinConfigurations.minimal-mac = inputs.nix-darwin.lib.darwinSystem { system = "aarch64-darwin"; modules = [ inputs.determinate.darwinModules.default inputs.home-manager.darwinModules.default ./hosts/minimal-mac/configuration.nix ]; };`.
- [x] 5.4 `formatter.x86_64-linux = inputs.nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;` — only this formatter row.

## Phase 6: Integration — Docs (English-only)

- [x] 6.1 `PARTITIONING.md`: manual gdisk UEFI/GPT (ESP typecode `EF00`, ~512 MB; root typecode `8300`, rest of disk), `mkfs.fat -F 32` ESP → `/mnt/boot`, `mkfs.ext4` root → `/mnt` (mount ESP after root), run `nixos-generate-config --show-hardware-config > /home/glats/minimal-nix/hosts/minimal-linux/hardware-configuration.nix` only after partitions are mounted, then `nixos-install --flake /home/glats/minimal-nix#minimal-linux`. No disko/declarative tools; attribute hostname changes to the `nixosConfigurations.*` key in `flake.nix`.
- [x] 6.2 `POST_INSTALL.md`: (a) macOS: install Determinate Nix (`https://determinate.systems/nix`) BEFORE first activation, then `darwin-rebuild switch --flake /home/glats/minimal-nix#minimal-mac`; (b) hostname defaults `minimal-linux`/`minimal-mac` noted as replaceable, citing `nixosConfigurations.*` / `darwinConfigurations.*` keys in `flake.nix`; (c) Codex auth covered as user-run commands: `codex login --device-auth` (SSH/headless), `codex login` (browser OAuth, macOS), `printenv OPENAI_API_KEY | codex login --with-api-key` (stdin); (d) states no credential is committed.

## Phase 7: Testing & Verification

- [x] 7.1 Stage first (nix requires tracked files): `git -C /home/glats/minimal-nix add -A`, then `nix fmt .#`.
- [x] 7.2 `nix flake check --no-build` in the repo → evaluates cleanly with no build actions.
- [x] 7.3 Selector evals: `nix eval .#nixosConfigurations.minimal-linux.config.system.build.toplevel.drvPath` -> drvPath; `nix eval .#darwinConfigurations.minimal-mac.config.system.build.toplevel.drvPath` -> drvPath, OR record eval-blocked if run on a Linux-only runner.
- [x] 7.4 HM package: `nix eval --apply 'map (p: p.name or "")' .#nixosConfigurations.minimal-linux.config.home-manager.users.claudio.home.packages` contains exactly one entry containing `codex` (length check `--apply 'builtins.length'` → 1); same two evals for `.#darwinConfigurations.minimal-mac.config.home-manager.users.claudio.home.packages` (Linux-blocked acceptable).
- [x] 7.5 Guards: `git -C /home/glats/minimal-nix remote -v` → empty; `grep -rn 'sops\|agenix\|omarchy\|disko\|COLORTERM=truecolor' /home/glats/minimal-nix --exclude-dir='.git'` → zero; `ls /home/glats/minimal-nix/hosts/minimal-linux/hardware-configuration.nix` → absent; docs greps: `grep -c 'codex login' /home/glats/minimal-nix/POST_INSTALL.md` ≥ 3 (all user-run), no Spanish text in the two docs.
- [ ] 7.6 `git -C /home/glats/minimal-nix add -A && git -C /home/glats/minimal-nix commit -m "feat: init minimal cross-platform flake (minimal-linux + minimal-mac)"`; verify `git -C /home/glats/minimal-nix log --oneline -1` and empty `git remote -v`.

# Proposal: Minimal Cross-Platform Flake

## Intent

Stand up a brand-new, minimal-but-robust Nix flake in an independent repo that configures two systems from one source: x86_64 NixOS (kmscon console) and aarch64-darwin macOS (Determinate Nix). Both hosts get Home Manager plus the OpenAI Codex CLI (`pkgs.codex`). The user's main `nixos-hosts` repo is too complex to copy; this extracts only the essential patterns.

## Scope

### In Scope

- New Git repo at `/home/glats/minimal-nix` (local init, no remote/origin).
- Single flat `flake.nix`: nixpkgs, nix-darwin, home-manager, determinate inputs; `nixosConfigurations.minimal-linux`, `darwinConfigurations.minimal-mac`, `homeConfigurations`, formatter.
- NixOS host `minimal-linux`: bootloader, networking, user `claudio`, kmscon (`hwRender = false`, `useXkbConfig = true`, default `xterm-256color`; no truecolor/`COLORTERM` claim).
- macOS host `minimal-mac`: `nix.enable = false`, Determinate Nix, user `claudio`, Home Manager wiring.
- Shared Home Manager module with `home.packages = [ pkgs.codex ]`.
- `POST_INSTALL.md` (Determinate/bootstrap, darwin-rebuild, Codex login) and `PARTITIONING.md` (manual UEFI/GPT).

### Out of Scope

- Secrets (sops/age), disko/declarative disks, flake-parts or other frameworks, remote Git/CI.
- Baking Codex auth into the flake; `hardware-configuration.nix` generation (first-install only).

## Capabilities

### New Capabilities

- `flake-bootstrap`: flake inputs, per-system outputs, formatter.
- `nixos-host`: NixOS system config incl. kmscon console.
- `darwin-host`: nix-darwin + Determinate Nix system config.
- `shared-home`: cross-platform Home Manager module (Codex CLI).
- `install-docs`: post-install + manual partitioning guides.

### Modified Capabilities

None.

## Approach

Exploration Approach 1: single flat `flake.nix` with inline host modules (no builders). Codex ships via the shared `home.packages`; auth is interactive and documented, never automated.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `/home/glats/minimal-nix/flake.nix` | New | Inputs + outputs |
| `hosts/minimal-linux/configuration.nix` | New | NixOS + kmscon |
| `hosts/minimal-mac/configuration.nix` | New | Darwin + Determinate |
| `home/shared.nix` | New | `pkgs.codex` |
| `POST_INSTALL.md`, `PARTITIONING.md` | New | Docs |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `pkgs.codex` heavy build (librusty_v8) | Med | Ensure `cache.nixos.org` reachable |
| kmscon is 256-color, not truecolor | High | Keep `xterm-256color`; never set `COLORTERM` |
| nix-darwin `stateVersion` mismatch | Low | Use `5`, verify at generation |
| Unknown-host GPU issues in kmscon | Med | `hwRender = false` |

## Rollback Plan

Delete `/home/glats/minimal-nix` (uncommitted work or `git reset`); nothing outside the repo is mutated. On a live host, `nixos-rebuild switch` / `darwin-rebuild switch` back to the prior generation.

## Dependencies

- nixpkgs `nixos-26.05`, nix-darwin `nix-darwin-26.05` (both confirmed available).

## Success Criteria

- [ ] `nix flake check --no-build` passes in the new repo.
- [ ] `minimal-linux` and `minimal-mac` evaluate to valid toplevel drvPaths.
- [ ] Both hosts expose `pkgs.codex` via Home Manager.
- [ ] kmscon config has `hwRender = false`, `useXkbConfig = true`, and no `COLORTERM`.
- [ ] Docs cover manual UEFI/GPT partitioning and Codex login.

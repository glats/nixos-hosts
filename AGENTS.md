# AGENTS.md - NixOS Multi-Host Configuration

## Overview

- **Hosts**: `rog` (desktop + nvidia + server), `thinkcentre` (headless + xrdp), `t14` (laptop, Omarchy/Hyprland), `mact2` (macOS via nix-darwin)
- **User**: glats (linux hosts), jcuzmar (mact2)
- **Stack**: NixOS Flakes + Home Manager + sops-nix + nix-darwin

## Project Structure

```
hosts/{hostname}/default.nix     # Host entry — imports modules directly
hosts/{hostname}/services/       # Host-specific services (rog has many)
modules/profiles/                # base.nix → desktop.nix → server.nix (chain)
modules/base/                    # Core system (users, nix, sops, zsh, etc.)
modules/desktop/                 # fonts, i18n, kmscon
modules/features/                # boot.nix, conky/, services/
modules/hardware/                # nvidia, amd-laptop, asus-fan-control
modules/networking/              # openssh, firewall, wol, avahi
modules/virtualisation/          # docker, libvirt
home-linux/                      # Home Manager modules (linux)
home-darwin/                     # Home Manager modules (macOS)
shared/                          # Cross-platform HM modules (opencode, sops, tmux)
darwin/                          # nix-darwin system modules (homebrew, settings)
lib/                             # mkHost.nix, mkDarwinHost.nix, packages.nix
overlays/                        # linux.nix, darwin.nix (imported via flake.nix)
pkgs/                            # Custom package derivations
bin/                             # Shell scripts (nixos-build, format-nix, code-work, etc.)
secrets/                         # sops-nix (encrypted — never edit directly)
```

## Commands

### Build & Deploy

| Task | Command | Verify |
|------|---------|--------|
| Build + switch | `nixos-build` | Check output for "switching to generation" |
| Safe rollout | `nixos-build safe` | Check→build→dry→switch sequence |
| Dry run | `nixos-build dry` | Shows what would change |
| Validate flake | `nix flake check --no-build` | Must exit 0 |

`nixos-build` auto-detects hostname, worktree, and `nh` vs `nixos-rebuild`. Use `--raw` to force `nixos-rebuild`.

### Formatting

| Task | Command | Verify |
|------|---------|--------|
| Full repo | `format-nix` | `git diff --stat` to review changes |
| Single file | `nix fmt -- <path>` | Check file was reformatted |

### Development

| Task | Command |
|------|---------|
| Build a single host without switching | `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` |
| Build HM alone | `nix build .#homeConfigurations.<user>@<host>.activationPackage` |
| Test t14 Omarchy | `nix build .#nixosConfigurations.t14.config.system.build.toplevel` (fastest check before full build) |
| Enter dev shell | `nix-shell -p <pkg>` if a tool is not installed |

### Git

| Task | Command | Verify |
|------|---------|--------|
| Stage all Nix changes | `git add -A` | `git diff --cached --stat` |
| Commit | `git commit -m "type(scope): message"` | `git log --oneline -3` |

## When Coding

1. **Research first** — never guess about how things work. Use MCP tools (github, context7, exa) to verify approaches, options, and best practices before writing.
2. **Edit Nix files** — after editing, run `format-nix` then `nix flake check --no-build` before declaring done.
3. **New module** — add to `modules/<category>/`, import in host `default.nix` or profile. If it's a feature/service, put it under `modules/features/services/`.
4. **Host-specific service** — place in `hosts/<hostname>/services/`, import in that host's `default.nix`.
5. **Secrets** — edit via `sops secrets/secrets.yaml`, never directly.
6. **hardware-configuration.nix** — never edit (auto-generated).
7. **Unfree package** — add to `allowUnfreePackages` list in the relevant host config.
8. **Verify** — after every change: `format-nix && nix flake check --no-build`. Fix any errors before moving on.

## When Reviewing

1. Check the diff covers what the task asked for
2. Verify `nix flake check --no-build` passes for at least one host
3. Confirm secrets are NOT exposed in plaintext
4. Check `opencode.json` / `AGENTS.md` changes don't break the config format

## Critical Rules

1. **hardware-configuration.nix**: Never edit
2. **Profile chain**: `base.nix` → `desktop.nix` → `server.nix`. Hosts import the profile they need
3. **features/* subcategories**: No `default.nix` — import services directly
4. **overlays.nix**: NOT a module — imported via `import` in `flake.nix`
5. **Home Manager**: Integrated via `modules/base/home-manager.nix`. Shared module list in `home-linux/shared-modules.nix` — single source of truth, do not duplicate
6. **Formatter**: `format-nix` for full-repo, `nix fmt -- <path>` for single file. Never use `nixfmt-rfc-style` directly
7. **t14 (Omarchy)**: Uses `omarchy-nix` + `nixos-hardware` via `extraModules` in `flake.nix`. HM config at `hosts/t14/home/omarchy.nix`, NOT in shared module list
8. **mact2 (macOS)**: Built via `mkDarwinHost`. Darwin modules in `darwin/`, HM modules in `home-darwin/`
9. **Home-conditional HM modules** (conky-rog, openfang): NOT in `shared-modules.nix` — appended per-host in `flake.nix` `homeConfigurations`

## When Blocked

| Problem | What to do |
|---------|-----------|
| `nix flake check` fails on unrelated host | The error may be pre-existing. Check if your changes touch that host. If not, note it and proceed. |
| Build takes too long | Use `--no-build` flags. Build only the host you're changing. |
| Option not found | Search via `nixos_nix` MCP tool with `action: "search", type: "options"` |
| Package not found | Search via `nixos_nix` MCP tool — channel is `unstable` |
| Permission denied | You may need `sudo` for system-level operations. Ask before using it. |
| `sops` file won't decrypt | You are NOT allowed to decrypt secrets. Read the encrypted file only. |

## Flake Inputs

| Input | Purpose |
|-------|---------|
| `nixpkgs` (nixos-unstable) | Packages |
| `home-manager` (master) | User config |
| `sops-nix` | Secrets |
| `nix-darwin` | macOS system config |
| `omarchy-nix` | Hyprland desktop for t14 |
| `nixos-hardware` | T14 AMD gen4 profile |
| `nix-colors` | Color schemes |
| `gentle-ai-src` / `engram-src` / `caveman-src` | OpenCode skills/plugins |
| `opencode` | Pre-built CLI (`fetchurl` in `pkgs/opencode/default.nix`) |

## Owned Repos

| Repo | Permission |
|------|-----------|
| `github.com/glats/omarchy-nix` | Full clone & push access — changes involving this repo can be committed and pushed directly |

# AGENTS.md - NixOS Multi-Host Configuration

## Overview

- **Hosts**: `rog` (MATE desktop via XRDP + NVIDIA + home server), `thinkcentre` (headless box accessed via XRDP), `t14` (ThinkPad laptop, Omarchy/Hyprland), `mact2` (Intel Mac via nix-darwin)
- **Users**: glats (Linux hosts), jcuzmar (mact2)
- **Stack**: NixOS Flakes + Home Manager (NixOS-integrated and standalone) + sops-nix + nix-darwin
- `/etc/nixos` is a symlink to this repo (`~/.nixos`) — scripts may reference either path.

## Project Structure

```
hosts/{hostname}/default.nix     # Host entry — flat explicit imports, one per line
linux/
  system/base|desktop|hardware|networking/  # NixOS modules by category
  system/features/               # boot.nix, gaming.nix, conky/options.nix (no default.nix)
  system/services/               # xrdp + portable services: media/, web/, network/
  system/virtualisation/         # docker, libvirt
  home/                          # Linux HM modules; shared-modules.nix = canonical list
darwin/system|services|home/     # nix-darwin modules; darwin/default.nix = entry point
shared/                          # Cross-platform HM modules (opencode, sops, tmux, ...)
lib/                             # mkHost.nix, mkDarwinHost.nix, packages.nix
overlays/                        # linux.nix, darwin.nix — imported via `import`, NOT modules
pkgs/                            # Custom package derivations
pkgs/nixos-scripts/              # Go module for operational scripts (Go-only policy) —
                                 #   source + tests + derivation co-located (src = ./.)
pkgs/nixos-scripts/cmd/<name>/main.go  # One thin Go entry point per operational binary
pkgs/nixos-scripts/internal/     # Shared Go packages (reporoot, gitutil, wg, nixbuild) —
                                 #   logic used by ≥2 scripts lives here, never copied between cmd/
bin/                             # test-tmux-resume + webcam only (documented Go-only exceptions)
secrets/                         # sops-encrypted: host/<hostname>/, shared/, user/
docs/                            # Operational runbooks (sops-new-host.md, multi-github-identity.md, wg-peer.md, ...)
```

## Commands

### Build & Deploy

`nixos-build` auto-detects platform (Linux vs Darwin), hostname, tools (`nh` preferred over nixos-rebuild/darwin-rebuild, `nom` for output), and worktrees (run inside `.worktrees/*` builds the local flake copy).

| Task | Command |
|------|---------|
| Build + switch | `nixos-build` (switch is default) |
| Safe rollout | `nixos-build safe` — check→build→dry→switch, stops on first failure |
| Dry activate | `nixos-build dry` |
| Next-boot / test activation | `nixos-build boot` / `nixos-build test` (NixOS only) |
| Update inputs + rebuild | `nixos-build upgrade` |
| Validate flake | `nixos-build check` (= `nix flake check`) |
| Force nixos-rebuild / disable nom | `--raw` / `--no-nom` |

**Required verification after every Nix change**: `format-nix && nix flake check --no-build`.

⚠️ `flake.nix` exposes `checks.x86_64-linux` containing all three NixOS hosts' toplevels, so plain `nix flake check` evaluates AND builds every host — always pass `--no-build` while iterating.

### Formatting

| Task | Command |
|------|---------|
| Full repo | `format-nix` (targets `/etc/nixos` = this repo via symlink; full-repo only, supports `--check`) |
| Single file | `nix fmt -- <path>` |

Formatter is `nixpkgs-fmt` set as flake `formatter`. Never invoke `nixpkgs-fmt <path>` directly — always go through `nix fmt`.

### Development

| Task | Command |
|------|---------|
| Build one host without switching | `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` |
| Build HM alone | `nix build .#homeConfigurations.<host>.activationPackage` — keys are bare hostnames, **not** `<user>@<host>` |
| Fastest eval sanity check | t14 build (command above) |
| Go scripts | `go -C pkgs/nixos-scripts test ./...` (plus `go build`/`go vet`/`go run ./cmd/<name>` with `-C pkgs/nixos-scripts` while iterating; deployed binaries are always Nix-built) |

## Home Manager Composition

- NixOS-integrated path: `linux/system/base/home-manager.nix` imports `hosts/<host>/home/default.nix`. Standalone `homeConfigurations` in flake.nix import the same per-host file.
- `linux/home/shared-modules.nix` is the single source of truth for shared Linux HM modules — do not duplicate the list elsewhere. Darwin equivalent: `darwin/home/shared-modules.nix`. Cross-platform modules live in `shared/` and are listed in both.
- **Host-conditional modules** (conky-rog, conky-thinkcentre, openfang) are NOT in shared-modules.nix — each `hosts/<host>/home/default.nix` extends the base list with its own extras.
- Per-host OpenCode provider override lives there too: `{ home.opencode.activeProviderName = "..."; }` (e.g. rog: `openai-opencode-balanced`, thinkcentre: `openai-medium`, mact2: `openai-medium-proxy`).

## When Coding

1. **Research first** — verify options/packages/APIs with MCP tools before writing; never guess option paths.
2. After editing any `.nix`: `format-nix && nix flake check --no-build` before declaring done.
3. New NixOS module → `linux/system/<category>/`, import in host `default.nix`. Flat imports only — no profile chains.
4. New portable service → `linux/system/services/<category>/`, importable by any Linux host.
5. New HM module → platform `home/` dir, or `shared/` if cross-platform; register in that platform's shared-modules list.
6. Secrets → `sops <specific-file>.yaml`. Agents must NEVER decrypt secrets — read ciphertext only. New host setup: follow `docs/sops-new-host.md`.
7. `hardware-configuration.nix` — never edit (auto-generated).
8. Unfree packages: `allowUnfree = true` is already global in flake.nix; license-gated packages additionally need host-level `allowUnfreePackages` + accept-license options (e.g. joypixels).
9. **Operational scripts are Go, never bash** — new/modified tooling goes in `pkgs/nixos-scripts/cmd/<name>/main.go` + shared logic in `pkgs/nixos-scripts/internal/`, shipped via `pkgs/nixos-scripts` (`buildGoModule`, `src = ./.`). See `shared/rules/go-scripts.md`. Only exceptions: `bin/test-tmux-resume`, `bin/webcam`. Verify with `go -C pkgs/nixos-scripts test ./...` plus the standard Nix gate.

## Reviewing

- Diff covers what was asked; `nix flake check --no-build` passes for at least the touched hosts.
- No secrets exposed in plaintext anywhere in the diff.
- Skill note: do NOT load `nix-verify` for non-Nix files (JSON/YAML/TOML/MD) even inside this repo — it is exclusively for Nix constructs.

## Critical Rules

1. **Flat imports**: each host imports exactly what it needs, one per line. No profile chains.
2. **features/* subcategories** have no `default.nix` — import files directly.
3. **Overlays** are `import`ed in flake.nix/lib builders, never added as modules.
4. **Formatter**: `format-nix` (full repo) / `nix fmt -- <path>` (single file); never formatter binaries directly.
5. **t14**: omarchy-nix + nixos-hardware T14 AMD gen4 profile arrive via `extraModules` in flake.nix. Its HM config block is `hosts/t14/home/omarchy.nix`, imported by t14's `home/default.nix`.
6. **mact2**: built via `mkDarwinHost` (includes Determinate module); username jcuzmar.
7. **nixpkgs is pinned to nixos-26.05** because 26.11 dropped x86_64-darwin and mact2 is an Intel Mac. Do not bump nixpkgs or nix-darwin (matched `nix-darwin-26.05` branch) until mact2 migrates to Apple Silicon. For the same reason `nix-vscode-extensions` is pinned to a pre-drop commit and gated behind `isDarwin`.
8. **Go-only scripts**: never write a new bash script for operational tooling. `pkgs/nixos-scripts` builds Go binaries from `cmd/` with `src = ./.` — the module dir is its own build sandbox (source, tests and derivation co-located; `secrets/` structurally out of reach).

## Secrets (sops-nix)

- Config at `.sops.yaml` (repo root). Layout: `secrets/host/<hostname>/*.yaml`, `secrets/shared/`, `secrets/user/`.
- Creation-rule ordering matters: specific path_regex rules must come BEFORE generic host catch-alls (e.g. `openai-proxy.yaml` is encrypted for rog+mact2+admin, placed above the rog-only rule).
- Adding a host: derive age key from SSH host key, add to `.sops.yaml` keys + relevant creation rules, re-encrypt with `sops updatekeys` — full runbook in `docs/sops-new-host.md`.

## When Blocked

| Problem | What to do |
|---------|-----------|
| `nix flake check` fails on unrelated host | May be pre-existing. If your changes don't touch that host, note it and proceed. |
| Option/package not found | Search with the `nixos_nix` MCP tool. Repo pins nixos-26.05 — results from other channels may differ. |
| Permission denied | System-level operations need sudo — ask before using it. |
| Encrypted file unreadable | You are NOT allowed to decrypt secrets. Read ciphertext only. |

## Owned Repos

| Repo | Permission |
|------|-----------|
| `github.com/glats/omarchy-nix` | Full clone & push access — changes involving this repo can be committed and pushed directly |

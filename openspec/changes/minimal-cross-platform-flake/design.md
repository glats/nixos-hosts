# Design: Minimal Cross-Platform Flake

## Technical Approach

Create `/home/glats/minimal-nix` as an independent local Git repository with one direct `flake.nix`, two small host modules, and one shared Home Manager module. The flake pins `nixos-26.05`, `nix-darwin-26.05`, Home Manager following nixpkgs, and Determinate 3. It exposes direct `nixosSystem`, `darwinSystem`, standalone `homeConfigurations`, and per-platform nixfmt formatters; it introduces no host builders or framework.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Flake shape | Direct, flat outputs and explicit module lists | `mkHost` helpers; flake-parts | Two hosts do not justify another abstraction layer. |
| Home Manager | Integrate HM in both system outputs; reuse `home/shared.nix`; also expose standalone homes | System packages; separate duplicated homes | Codex state is per-user, while reuse keeps its package declaration identical on both systems. |
| macOS Nix | Import `determinate.darwinModules.default` and set `nix.enable = false` | nix-darwin-managed Nix; Homebrew/npm Codex | Prevents two Nix installers from managing macOS while retaining a locked configuration. |
| kmscon/Codex terminal | `hwRender = false`, `useXkbConfig = true`, default `xterm-256color`, no `COLORTERM` | GPU rendering; forced truecolor | Software rendering is safer on unknown GPUs; kmscon is 256-color and false truecolor breaks Codex rendering. |
| Codex auth | Document interactive login only | Declarative credentials or secret management | Credentials belong in the user's Codex store, never in the repository. |

## Data Flow

    flake.locked inputs
           │
           ├── nixosConfigurations.minimal-linux ──→ hosts/minimal-linux ──┐
           └── darwinConfigurations.minimal-mac ──→ hosts/minimal-mac ────┤
                                                                         ▼
                                                               Home Manager
                                                                         │
                                                    home/shared.nix → pkgs.codex
                                                                         │
                                                        ~/.codex auth/config (interactive)

On Linux, kmscon starts with its honest `xterm-256color` capability; Codex selects ANSI-256 when `COLORTERM` is absent. On macOS, the normal terminal and Determinate-managed daemon serve the same Home Manager package.

## File Changes

| File | Action | Description |
|---|---|---|
| `/home/glats/minimal-nix/flake.nix` | Create | Four inputs, direct system/HM outputs, and formatters for `x86_64-linux` and `aarch64-darwin`. |
| `/home/glats/minimal-nix/hosts/minimal-linux/configuration.nix` | Create | Boot, networking, `claudio`, integrated HM, and kmscon settings. |
| `/home/glats/minimal-nix/hosts/minimal-linux/hardware-configuration.nix` | Generate during install | Hardware-specific output from `nixos-generate-config`; never hand-authored. |
| `/home/glats/minimal-nix/hosts/minimal-mac/configuration.nix` | Create | Determinate module settings, `claudio`, and integrated HM. |
| `/home/glats/minimal-nix/home/shared.nix` | Create | Shared `home.packages = [ pkgs.codex ]`. |
| `/home/glats/minimal-nix/POST_INSTALL.md` | Create | Bootstrap, rebuild, host-name replacement, and Codex login instructions. |
| `/home/glats/minimal-nix/PARTITIONING.md` | Create | Manual AMD64 UEFI/GPT partition, format, mount, and generated-hardware steps. |

## Interfaces / Contracts

The flake MUST provide these stable selectors:

```nix
nixosConfigurations.minimal-linux
darwinConfigurations.minimal-mac
homeConfigurations."claudio@minimal-linux"
homeConfigurations."claudio@minimal-mac"
```

`minimal-linux` MUST configure `services.kmscon.enable`, `hwRender = false`, and `useXkbConfig = true`; it MUST NOT set `COLORTERM` or a truecolor terminal override. `minimal-mac` MUST import the Determinate Darwin module and set `nix.enable = false`. Both integrated and standalone HM paths MUST import `home/shared.nix`, set the appropriate username/home directory/state version, and yield `pkgs.codex` on the target platform.

`POST_INSTALL.md` MUST direct macOS users to install Determinate Nix before the first `darwin-rebuild`/`nix run nix-darwin` activation. It MUST document `codex login` for macOS, `codex login --device-auth` for kmscon, and `printenv OPENAI_API_KEY | codex login --with-api-key` as an interactive stdin path; it MUST state that no credential is committed.

## Testing Strategy

| Layer | What to test | Approach |
|---|---|---|
| Static | Syntax, locks, formatter, declared outputs | `nix fmt -- .` then `nix flake check --no-build`. |
| Evaluation | Linux and Darwin system closures; both HM activation packages | Evaluate each configured `...config.system.build.toplevel.drvPath` and `homeConfigurations` activation `drvPath`. |
| Manual | Codex availability and terminal/auth behavior | On each host run `codex --version`; use documented login. On Linux confirm `echo $TERM` is `xterm-256color` and `COLORTERM` is unset. |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary is introduced. Documentation lists operator commands but ships no command wrapper or automation.

## Migration / Rollout

No migration required. Bootstrap macOS with Determinate Nix, then activate the Darwin selector. During Linux installation, create the documented UEFI/GPT layout, generate the hardware module into the host directory, and install the Linux selector. Roll back an activated machine to its previous Nix generation; discard the new local repository to abandon the design.

## Open Questions

- [ ] None; the generated Linux hardware module is intentionally host-specific and produced at installation time.

# Tasks: Rebuild Agent Context

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~290 (AGENTS.md full rewrite ~270 + ~20 Nix edits) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | single PR |
| Delivery strategy | ask-on-risk (no risk triggered) |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Trim `AGENTS.md`, repoint `agentsMdSources`, remove OpenCode global generation | PR 1 | `nix eval .#homeConfigurations.t14.activationPackage.drvPath` | `nixos-build` on one host, then inspect `~/.claude/CLAUDE.md` populated and `~/.config/opencode/AGENTS.md` absent | Revert the three files; activation restores prior generated outputs |

## Phase 1: Content — rewrite root AGENTS.md

- [x] 1.1 Rewrite `AGENTS.md` (185 → ≤85 lines) to concise Nix facts only: Overview (hosts, users, stack, `/etc/nixos` symlink), Commands (build/deploy, tiered verification, formatting, Go scripts), Critical Rules (flat imports, Go-only scripts, sops, never edit `hardware-configuration.nix`, 26.05 pin, overlays imported not modules), language contract folded once; cut RTK prose to ~2 lines, the Project Structure tree, the When Blocked table, and formatting prose duplicated from `output-format.md`.
- [x] 1.2 Add concise Omarchy Nix/t14 section with the three required facts — pinned fork `github:glats/omarchy-nix` commit `5c01ca6` (`flake.nix` (read-only) L21-25), t14-only `extraModules` = `inputs.omarchy-nix.nixosModules.default` + `lenovo-thinkpad-t14-amd-gen4` (`flake.nix` (read-only) L292-295), `hosts/t14/home/omarchy.nix` importing `homeManagerModules.default` — plus short extras: `btop` HM module shared on Linux hosts, `t14QuattroOverlay` exposes `omarchy-runtime`/`quickshell` only to t14; no OpenCode global-context duplication.

## Phase 2: Nix assembly

- [x] 2.1 `shared/ai-assets.nix`: change `agentsMdSources` default (L33-41) from the upstream skills-index + two rule fragments to `[ ../AGENTS.md ]`; keep the `types.listOf types.path` interface and description.
- [x] 2.2 `shared/opencode/runtime-config.nix`: remove `AGENTS.md` from the mutable-file conversion loop (L172 `for file in opencode.json AGENTS.md package.json .gitignore tui.json`).
- [x] 2.3 `shared/opencode/runtime-config.nix`: delete the `ag_md` concatenation block (L249-255).
- [x] 2.4 `shared/opencode/runtime-config.nix`: in `makeOpencodeConfigMutable-default`, add `rm -f "$runtime_dir/AGENTS.md"` to remove the legacy global file; leave skills, commands, plugins, and JSON generation unchanged.

## Phase 3: Verification (named by design)

- [x] 3.1 Static: review rewritten `AGENTS.md` against `flake.nix` (read-only), `hosts/t14/default.nix` (read-only), `hosts/t14/home/default.nix` (read-only), `hosts/t14/home/omarchy.nix` (read-only) — ≤~85 lines, Nix-only, contains the three Omarchy/t14 facts, no duplicated or non-Nix prose.
- [x] 3.2 Module eval: `nix eval .#homeConfigurations.{rog,thinkcentre,t14,macm5}.activationPackage.drvPath`; inspect `agentsMdSources` resolves to exactly one path, the repo-root AGENTS.md. (rog, thinkcentre, and t14 passed; macm5 is not evaluable from x86_64-linux because a required `gentle-ai-assets` derivation requires `aarch64-darwin`; its option value evaluated to the single root source.)
- [x] 3.3 Generated behavior: inspect `home.activation.deployClaudeCodeAssets.data` (Claude activation carries the root source) and `home.activation.makeOpencodeConfigMutable-default.data` (removes, does not create, the global `AGENTS.md`); run `git diff --exit-code -- shared/claude-code.nix` (read-only) proving verify-only.
- [x] 3.4 Repository gate: `nix fmt -- shared/ai-assets.nix shared/opencode/runtime-config.nix`, then `nix flake check --no-build`.

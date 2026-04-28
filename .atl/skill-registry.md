# Skill Registry for `.nixos`

**Generated**: 2026-04-26 | **Mode**: engram | **Strict TDD**: `false` (no test runner)

---

## Project Context

| Property | Value |
|----------|-------|
| Project | `.nixos` (NixOS multi-host configuration) |
| Hosts | `rog` (ASUS ROG laptop), `thinkcentre` (Lenovo ThinkCentre) |
| User | `glats` on both hosts |
| Stack | Nix Flakes, NixOS, Home Manager, sops-nix |
| Flake inputs | `nixos-unstable`, `home-manager/master`, `sops-nix`, `nix-colors` |
| Formatter | `nixfmt` (via `format-nix` command) |
| Validation | `nix flake check`, `nixos-rebuild switch` (no unit tests) |

---

## SDD Workflow Configuration

### Phases
```
explore → propose → spec → design → tasks → apply → verify → archive
```

### Build Commands (per AGENTS.md)
| Task | Command |
|------|---------|
| Build & activate | `nixos-build switch` |
| Build & upgrade | `nixos-build upgrade` |
| Show changes | `nixos-build dry` |
| Validate flake | `nixos-build check` |
| Format all nix | `format-nix` |

### Critical Rules (per AGENTS.md)
- **Never edit** `hardware-configuration.nix` — auto-generated
- **Category `default.nix`** — each `modules/{category}/default.nix` re-exports all modules
- **overlays.nix** is NOT a NixOS module — imported via `import` in `flake.nix`
- **Home Manager** is NixOS-integrated only via `modules/core/home-manager.nix`
- **Unfree packages** — listed in `hosts/rog/default.nix`
- **All code in English** — no mixed languages

---

## SDD Skills

| Skill | Trigger | Path |
|-------|---------|------|
| `sdd-init` | Initializing SDD in a project | `~/.config/opencode/skills/sdd-init/SKILL.md` |
| `sdd-onboard` | End-to-end SDD workflow walkthrough | `~/.config/opencode/skills/sdd-onboard/SKILL.md` |
| `sdd-explore` | Exploring and investigating ideas | `~/.config/opencode/skills/sdd-explore/SKILL.md` |
| `sdd-propose` | Creating change proposals | `~/.config/opencode/skills/sdd-propose/SKILL.md` |
| `sdd-spec` | Writing specifications | `~/.config/opencode/skills/sdd-spec/SKILL.md` |
| `sdd-design` | Creating technical design documents | `~/.config/opencode/skills/sdd-design/SKILL.md` |
| `sdd-tasks` | Breaking down changes into tasks | `~/.config/opencode/skills/sdd-tasks/SKILL.md` |
| `sdd-apply` | Implementing tasks from specs | `~/.config/opencode/skills/sdd-apply/SKILL.md` |
| `sdd-verify` | Validating implementation | `~/.config/opencode/skills/sdd-verify/SKILL.md` |
| `sdd-archive` | Syncing delta specs to main | `~/.config/opencode/skills/sdd-archive/SKILL.md` |

---

## NixOS-Specific Skills

| Skill | Trigger | Path |
|-------|---------|------|
| `nix-verify` | Editing `.nix` files — verify packages, options, Nix functions | `~/.config/opencode/skills/nix-verify/SKILL.md` |

---

## Communication Skills

| Skill | Trigger | Path |
|-------|---------|------|
| `caveman` | Token efficiency, caveman mode | `~/.config/opencode/skills/caveman/SKILL.md` |
| `caveman-commit` | Writing commit messages | `~/.config/opencode/skills/caveman-commit/SKILL.md` |
| `caveman-review` | PR code review | `~/.config/opencode/skills/caveman-review/SKILL.md` |
| `branch-pr` | Creating PR or preparing changes for review | `~/.config/opencode/skills/branch-pr/SKILL.md` |
| `issue-creation` | Creating GitHub issues or reporting bugs | `~/.config/opencode/skills/issue-creation/SKILL.md` |
| `judgment-day` | Adversarial code review | `~/.config/opencode/skills/judgment-day/SKILL.md` |

---

## Convention Files

| File | Purpose |
|------|---------|
| `AGENTS.md` | Project overview, structure, build commands, critical rules |
| `lib/mkHost.nix` | Helper function for multi-host NixOS configurations |
| `flake.nix` | Flake entry with nixosConfigurations for all hosts |

---

## Architecture Summary

**Skill Distribution**:
- **SDD skills**: 10 `sdd-*` skills in `~/.config/opencode/skills/`
- **NixOS validation**: `nix-verify` for NixOS-specific package/option verification
- **Communication**: `caveman*`, `branch-pr`, `issue-creation`, `judgment-day`

**Validation Strategy**:
- `nix flake check` — validates flake syntax and structure
- `nixos-rebuild switch` — builds and activates configuration
- No unit tests (infrastructure code, not application code)
- Strict TDD Mode disabled — no test runner for NixOS configs
# Design: Adopt Archify Skill

## Technical Approach

Package the verified upstream `tt-a1i/archify` revision `d673e8300df60a5c8166abe78787fdc78f6b8000`, then copy its installed tree into the existing local skill source. The existing OpenCode and Claude Code activation unions deploy that source to both agent directories, so no installer, wrapper, runtime download, or flake input is needed.

At this revision, `archify/` is Node >=18 ESM version `2.17.0-dev.1`, with a v3 `package-lock.json`; runtime-used modules are declared as dev dependencies. NixOS 26.05 `buildNpmPackage` supports `sourceRoot`, `npmDepsHash`, `dontNpmBuild`, and a custom install phase. Set `sourceRoot = "source/archify"` so the dependency fetcher finds the lockfile. Skip a nonexistent npm build script and copy the post-`npm ci` tree, including `node_modules`; the default install hook prunes dev dependencies and emits only npm-pack files.

## Architecture Decisions

| Decision | Choice and rationale |
|---|---|
| Ownership | Create `pkgs/archify-skill/default.nix`, expose it in `lib/packages.nix`, and inject it into `local-ai-assets`. This makes source and closure reviewable while retaining `local-ai-assets` as the sole deployed local-skill source. |
| Fixed inputs | Use `fetchFromGitHub` revision `d673…8000`, source hash `sha256-0GKYLvKBGJ5Skwm2vOrdAQ1x9PfMqzXpmRsT+UMRaN4=`, `sourceRoot = "source/archify"`, `npmDepsHash = sha256-yKsABEczUQhfBUDp85XEwH26aDlKXWcOdR6TOH7/9uE=`, and `dontNpmBuild = true`. These values were generated with the locked 26.05 builder; a native Linux package build passed `doctor` and the disabled update checker. |
| Retained files | Custom `installPhase` copies `.` to `$out`, preserving `SKILL.md`, renderers, assets, scripts, lockfile, tests, and installed modules. `archify.zip`, `npx`, node2nix/dream2nix, and the default npm hook are rejected because they do not provide this immutable runnable tree. |
| Environment | Under `home.ai-assets.enable`, set `home.sessionVariables.ARCHIFY_UPDATE_CHECK_DISABLED = "1"`. Both profiles enable this shared option; upstream reports `silent/disabled` without network or reminder-state I/O. |
| Output policy | `docs/archify.md` allows explicit, reviewed requests using public revision-pinned facts only. `.gitignore` ignores `docs/artifacts/archify/`; previews, browser opening, automatic output, sensitive topology, and diagrams as behavior proof are prohibited. |

## Data Flow

    fixed GitHub source + fixed npm cache
                  │ buildNpmPackage / npm ci
                  ▼
      complete `archify` tree including node_modules
                  │
    local-ai-assets/share/local-ai/skills/archify
                  │ existing ordered skillSources union
          ┌───────┴────────┐
          ▼                ▼
    ~/.config/opencode/skills/archify   ~/.claude/skills/archify

`local-ai-assets` copies its maintained sources first and the Archify output second. Existing cmp-guarded union cleanup removes only Archify files after rollback.

## File Changes

| File | Action | Description |
|---|---|---|
| `pkgs/archify-skill/default.nix` | Create | Fixed-source, fixed-npm, complete-tree derivation. |
| `pkgs/local-ai-assets/default.nix` | Modify | Accept and copy `archify-skill` to `share/local-ai/skills/archify`. |
| `lib/packages.nix` | Modify | Define the package before injecting it into `local-ai-assets` for every system. |
| `shared/ai-assets.nix` | Modify | Declare the shared disabled-update session variable. |
| `.gitignore` | Modify | Ignore `docs/artifacts/archify/`. |
| `docs/archify.md` | Create | Safe-use and reviewed-output policy. |
| `shared/opencode/runtime-config.nix`, `shared/claude-code.nix`, `shared/opencode.nix`, `overlays/linux.nix`, `overlays/darwin.nix`, `flake.nix` | No change | Existing unions, package closure, and all-system outputs suffice. |

## Interfaces / Contracts

`pkgs.archify-skill` is an internal all-platform derivation consumed by `local-ai-assets`; it is not added to overlays. Its composition contract is:

```nix
cp -r "$archifySkill" "$out/share/local-ai/skills/archify"
```

For an upstream update, set source `hash` and `npmDepsHash` to `lib.fakeHash` separately, build, copy each reported `got: sha256-…`, then rebuild and run the gates. Never infer hashes.

## Testing Strategy

| Layer | Proof |
|---|---|
| Package | Build native `.#packages.x86_64-linux.archify-skill`; assert `SKILL.md` and `node_modules`; run `ARCHIFY_UPDATE_CHECK_DISABLED=1 node bin/archify.mjs doctor` and `scripts/check-update.mjs` (`silent/disabled`). |
| Deployment | After native Home Manager activation, compare both agent directories with the package tree and inspect the session variable. |
| Hosts | Run `format-nix`, `nix flake check --no-build`, and native Linux/Darwin package builds where executors exist. |

## Threat Matrix

| Boundary | Applicability | Design response / RED tests |
|---|---|---|
| Documentation-like paths | N/A — no classifier or executable dispatch changes. | None. |
| Git repository selection | N/A — no VCS command. | None. |
| Commit state | N/A — no commit automation. | None. |
| Push state | N/A — no push automation. | None. |
| PR commands | N/A — no PR automation. | None. |

## Migration / Rollout

No option migration is required. Validate Linux locally and x86_64-darwin on mact2 or another native Darwin executor. The current Linux executor cannot evaluate mact2 to a derivation: evaluation forces x86_64-darwin `gentle-ai-assets` and fails with platform mismatch. Record this limitation; do not substitute diagram output as proof.

Rollback reverts the six changed/created files. Union cleanup removes deployed Archify while Node, unrelated skills, px0, and secrets remain unchanged.

## Open Questions

None.

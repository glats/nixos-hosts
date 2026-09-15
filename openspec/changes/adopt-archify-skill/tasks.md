# Tasks: Adopt Archify Skill

## Review Workload Forecast

| Field | Value |
|---|---|
| Estimated changed lines | 90–160 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|---|---|---|---|---|---|
| 1 | Package and compose pinned Archify | PR 1 | `nix build .#packages.x86_64-linux.archify-skill` | `archify doctor` offline | Revert `pkgs/archify-skill`, `pkgs/local-ai-assets`, `lib/packages.nix` |
| 2 | Apply policy and cross-platform gates | PR 1 | `format-nix && nix flake check --no-build` | Static HTML fixture smoke; Darwin native build when available | Revert `shared/ai-assets.nix`, `.gitignore`, `docs/archify.md` |

## Phase 1: Pinned Package Foundation

- [x] 1.1 Create `pkgs/archify-skill/default.nix` with revision `d673e8300df60a5c8166abe78787fdc78f6b8000`, `fetchFromGitHub`, `sourceRoot = "source/archify"`, fixed source/npm hashes, `dontNpmBuild = true`, and install preserving `node_modules`.
- [x] 1.2 Generate/review source and npm hashes independently: temporarily use `lib.fakeHash`, run the native package build, replace each reported `got:` hash, and confirm no inferred or mutable hash remains (Req. 1).

## Phase 2: Asset Wiring and Policy

- [x] 2.1 Modify `pkgs/local-ai-assets/default.nix` to accept `archify-skill` and copy it to `share/local-ai/skills/archify`; wire the package in `lib/packages.nix` for Linux and Darwin (Req. 1–2).
- [x] 2.2 Set shared `home.sessionVariables.ARCHIFY_UPDATE_CHECK_DISABLED = "1"` in `shared/ai-assets.nix`; do not alter agent unions or add px0 (Req. 2–3).
- [x] 2.3 Add `docs/artifacts/archify/` to `.gitignore` and create `docs/archify.md` covering explicit reviewed public facts, secret/topology rejection, ignored output, no preview/browser/automatic generation, and diagrams as assistive only (Req. 3–4).

## Phase 3: Verification and Rollback Proof

- [x] 3.1 Build `.#packages.x86_64-linux.archify-skill`; assert `SKILL.md`, `node_modules`, lockfile, and runnable scripts; run `ARCHIFY_UPDATE_CHECK_DISABLED=1 node bin/archify.mjs doctor` and the update checker, expecting offline disabled/silent behavior (Req. 1, 3).
- [x] 3.2 Run the documented Archify CLI against a harmless local static-HTML fixture, assert a reviewable HTML artifact under ignored `docs/artifacts/archify/`, then remove it; do not use secrets, topology, preview, browser opening, or artifact output as proof (Req. 4).
- [x] 3.3 Run `format-nix && nix flake check --no-build`; build/evaluate Linux and native `x86_64-darwin` where available, record missing Darwin executor honestly, and verify activation copies both agent trees identically plus scoped rollback cleanup (Req. 2, 5–6).

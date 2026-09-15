# Proposal: Adopt Archify Skill

## Intent

Provide a reproducible on-demand Archify skill to both agents without mutable installers, update traffic, or a runtime service.

## Scope

### In Scope
- Pin `tt-a1i/archify` at reviewed commit `d673e8300df60a5c8166abe78787fdc78f6b8000` with a fixed Nix source hash; do not add a flake input.
- Build upstream `archify/` from its committed `package-lock.json` with a Nix npm dependency hash, then copy its complete runnable tree into `local-ai-assets` at `share/local-ai/skills/archify`.
- Deploy that source through the existing ordered `home.ai-assets.skillSources` union to OpenCode and Claude Code on rog, thinkcentre, t14, and mact2.
- Set `ARCHIFY_UPDATE_CHECK_DISABLED=1` through shared Home Manager session variables; document explicit-request-only output under ignored `docs/artifacts/archify/`.
- Require revision-pinned, reviewed/public source facts; prohibit secrets and sensitive topology in generated inputs or output; treat diagrams as assistive documentation, not runtime proof.

### Out of Scope
- px0 adoption, packaging, or local-server operation; defer pending its unresolved #75/#77 origin/CSP defects and absent Nix package.
- `npx skills`, mutable runtime installation, bespoke OpenCode/Claude installers, Bash helpers, and a new flake input.
- Automatic generation, preview servers, browser opening, or generated artifacts in runtime/verification evidence.

## Capabilities

### New Capabilities
- `archify-diagram-generation`: Pinned Archify deployment and safe on-demand artifact policy for both agents.

### Modified Capabilities
- None.

## Approach

Upstream is a complete skill directory (`SKILL.md`, renderers, assets, scripts, Node CLI), not a static prompt. Add an Archify derivation using `fetchFromGitHub` plus `buildNpmPackage` with fixed source/npm hashes; retain its runnable tree and `node_modules`. Pass it to `pkgs/local-ai-assets`, which copies it to `share/local-ai/skills/archify`; do not source-vendor a mutable snapshot. Node is already declarative everywhere: Linux shared Neovim and Darwin shared packages include `nodejs`; no new exposure is needed. Set the flag in `shared/ai-assets.nix` for both launches.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `pkgs/local-ai-assets/` | Modified/New | Pinned Archify npm derivation and asset composition |
| `shared/ai-assets.nix` | Modified | Shared update-check environment |
| `.gitignore`, `docs/archify.md` | Modified/New | Ignored artifact directory and safe-use policy |
| `lib/packages.nix` | Modified | Wire the internal derivation into local assets |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Artifact exposes topology | Medium | Explicit request, public pinned facts, ignore policy, review |
| npm build differs by platform | Low | Fixed hashes; evaluate Linux and x86_64-darwin |

## Rollback Plan

Revert the local asset/derivation, environment flag, and artifact-policy changes; activation orphan cleanup removes the deployed `archify` directory without affecting other skills.

## Dependencies

- Node >=18 already supplied on all affected hosts; fixed upstream and npm hashes must be generated and reviewed.

## Success Criteria

- [ ] Both agents receive identical pinned Archify skill files after activation on Linux and mact2.
- [ ] `archify doctor` works offline with Node >=18 and no update-manifest request.
- [ ] `format-nix` and `nix flake check --no-build` pass; artifact policy is documented and ignored.

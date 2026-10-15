# Proposal: Gentle AI 4.1.1 ODD on rog

## Intent

Make Gentle AI v4 ODD usable in opencode2 on rog by reusing `feature/gentle-ai-4` (`3e2078e8`), not rebuilding its plumbing. Supersedes `gentle-ai-v4-odd-v2-only`; preserve its history.

## Scope

### In Scope
- Pin v4.1.1: `898d3976e8049a7238eaa7de60bff325c30d2b3d`; align binary, rendered assets, reconciliation, and ODD routing.
- rog profile: `anthropic-openai-opencode`. Remove `opencode-free`, `anthropic-opencode-free`, `anthropic-opencode-go`; retain NVIDIA nemotron alias and native V2 projection. Removed audit comments are acceptable.
- Remap SDD phases to `gentle-ai-explore`, `gentle-ai-worker`, `gentle-ai-verify`; retire managed SDD runtime assets.

### Out of Scope
- Deployment to thinkcentre/t14/macm5, private paid model cycles, old threat matrices/receipts, unrelated cleanup, and historical OpenSpec deletion.
- Activation, commits, push, and PR without separate authorization.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `gentle-ai-declarative-runtime`: v4 pin, ODD agents/plugins, ownership-safe retirement, approved provider changes, and rog-first acceptance replace conflicting v2.5/SDD gates.

## Approach

Use a new branch/worktree from `feature/gentle-ai-4`; leave dirty master's overlapping `hosts/rog/home/default.nix` and `shared/opencode/providers-base.nix` untouched. Port only confirmed decisions.

v4.1 adds installed-SDD cleanup, proportionate high-risk native review (contract 1.3.0), updated ODD guidance, and V2 relay refusal causes. v4.1.1 re-tags the released v4.1.0 commit for consistent checksums. Module `/v4`, Go 1.25.10, exporter APIs, agent names, and relay asset path remain compatible. Refresh rendered bytes; revalidate vendorHash (dependency versions unchanged; ANSI becomes direct), scanner patch, and exporter assertions.

Update reconciliation revision arguments to the actual source SHA, including sibling consumers: they stamp manifest provenance and constrain pending retries, not source fetching. Finish any pending old generation first. Keep Home Manager deployment authority; do not run upstream install/sync.

## Affected Areas

- `flake.nix`, `flake.lock`, `pkgs/gentle-ai/default.nix`: pin/version/ldflags/hash.
- `pkgs/gentle-ai-assets/{default.nix,render.nix,render_test.go}`: version/render compatibility.
- `shared/opencode/{agents.nix,providers-base.nix,runtime-config.nix,v2-agents.nix}`, `hosts/rog/home/default.nix`: routing/runtime.
- `shared/{ai-assets-tree.nix,claude-code.nix,skills.nix}`, `pkgs/nixos-scripts/{cmd/ai-assets-reconcile,internal/aiassets}`: reuse ownership plumbing.

## Risks

Medium: edited assets/symlinks or pending journals block activation; retain fail-closed reconciliation. Shared changes affect other hosts' evaluation despite deferred deployment.

## Rollback Plan

Before authorized switch, retain the previous NixOS/Home Manager generations and back up managed mutable assets/manifests. Return to the previous NixOS generation and restore only that asset snapshot if necessary; preserve credentials, sessions, and history.

## Dependencies

Existing branch plumbing, available upstream source, and explicit activation authorization.

## Success Criteria

- [ ] rog toplevel and Home Manager builds pass; focused existing checks pass.
- [ ] `nix flake check --no-build`, macm5 Darwin and standalone Home Manager evaluations pass.
- [ ] Separately authorized `nixos-build switch` on rog leaves `home-manager-glats.service` green.
- [ ] Live `gentle-ai --version` reports `4.1.1`; reconciler exists; V2 has v4 assets and no `sdd-task-result.ts`; upstream V2 review transport remains.
- [ ] User completes ONE real ODD session in opencode2.

# Proposal: Harness Token Efficiency

## Intent

Pilot RTK against high-volume shell output. Existing routing, compaction, MCP pruning, Caveman, Cavecrew, Ponytail, and Engram address different costs; RTK complements them by rewriting supported commands. Its advertised 60–90% applies only to command-output reduction, so adoption requires local evidence.

## Scope

### In Scope
- Expose and install pinned `pkgs.rtk` 0.41.0 on rog, thinkcentre, t14, and mact2; x86_64-darwin is supported.
- Deploy RTK 0.41.0's fail-open OpenCode plugin and native Claude Code `PreToolUse` command (`rtk hook claude`) declaratively, preserving existing settings and disabling telemetry while retaining local gain tracking.
- Measure representative Git, `go -C pkgs/nixos-scripts test ./...`, `nix flake check --no-build`, and `nixos-build` sessions with `rtk gain --project` and `rtk gain --project --history`.

### Out of Scope
- Hermes / `NousResearch/hermes-agent`; it remains a separate platform decision.
- New flake inputs, custom filters, shell scripts, secrets, or total-spend claims.

## Capabilities

### New Capabilities
- `harness-token-efficiency`: Declarative RTK installation, runtime interception, privacy posture, measurement, and rollback across supported hosts.

### Modified Capabilities
None.

## Approach

Vendor RTK 0.41.0's reviewed `rtk.ts`, register it in the managed-plugin lifecycle, and enable it in the shared profile. OpenCode 1.18.18 supports its `tool.execute.before` mutation contract and global TypeScript loading. Merge Claude's Bash matcher into generated `settings.json`; built-in Read/Grep/Glob bypass it. Unsupported commands pass through unchanged.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/packages.nix`, `shared/opencode.nix` | Modified | Expose/install RTK and disable telemetry. |
| `shared/opencode/{plugins.nix,runtime-config.nix,opencode-profile.nix,rtk.ts}` | Modified/New | Manage plugin lifecycle. |
| `shared/claude-code.nix` | Modified | Merge the native Bash hook without clobbering settings. |
| `docs/rtk-pilot.md` | New | Record commands, gain numbers, limitations, and recall/disable guidance. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Filtering hides useful output | Medium | Validate failures/history; document raw bypass and exclusions. |
| Command rewrite changes behavior | Low | Compare exit codes/results for representative commands; plugin fails open. |
| Savings are overstated | Medium | Report `rtk gain` numbers as shell-output estimates only. |

## Rollback Plan

Revert the single change to remove package exposure, plugin, hook, telemetry config, and guide. Plugin failures already leave commands unchanged.

## Dependencies

- Pinned nixpkgs `rtk` 0.41.0; no new input or secret.

## Success Criteria

- [ ] `format-nix && nix flake check --no-build` passes.
- [ ] All four hosts expose RTK; OpenCode and Claude Code complete representative commands with unchanged outcomes and exit codes.
- [ ] `rtk gain --project` reports non-zero commands, estimated tokens saved, and savings percentage; history identifies rewrites and passthrough gaps.
- [ ] Telemetry is disabled and fail-open/raw recovery is verified.

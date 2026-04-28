# Proposal: gentle-ai-migration

## Intent

Migrate NixOS opencode configuration from heavily customized setup to upstream-first approach. Current configuration has accumulated 10+ customizations without clear necessity tracking. We need a clean migration path that tests upstream behavior first, then adds back only what's essential.

## Scope

### In Scope
- Phase 0: Backup current state (config, skills, wrappers)
- Phase 1: Create upstream-only derivation for reference
- Phase 2: Analyze upstream fit in NixOS environment
- Phase 3: Test upstream using lab runtime (parallel testing)
- Phase 4: Gradual customization restoration (P0→P3 priority)
- Phase 5: Production promotion

### Out of Scope
- Direct production replacement without testing
- Preserving all existing customizations unconditionally
- Changes to core NixOS system configuration
- Modifications to hardware-configuration.nix

## Capabilities

### New Capabilities
- `upstream-runtime`: Upstream-only opencode derivation for lab testing
- `lab-environment`: Isolated test environment for parallel validation
- `gradual-customization`: Systematic restoration of customizations by priority
- `migration-rollback`: Safe rollback to previous configuration

### Modified Capabilities
- `opencode-home-module`: Update to support both current and upstream runtimes
- `opencode-wrapper`: Transition from custom to upstream-first with selective additions

## Approach

**Upstream-First Principle**: Start with clean upstream, test thoroughly, add back only proven customizations.

1. **Backup Phase**: Full snapshot of ~/.local/share/opencode/, skills/, wrappers
2. **Reference Phase**: Build upstream-only derivation (no patches, no customizations)
3. **Analysis Phase**: Compare runtime behavior, identify NixOS-specific needs
4. **Testing Phase**: Use lab runtime alongside production for validation
5. **Migration Phase**: Gradual P0→P3 customization restoration with testing
6. **Production Phase**: Promote validated configuration as default

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `modules/home/opencode/` | Modified | Support dual runtime (current + upstream) |
| `wrappers/opencode/` | Modified | Split into current/ and upstream/ variants |
| `~/.local/share/opencode/` | Backup | Full backup before migration |
| `~/.config/opencode/skills/` | Backup | All skills byte-identical, but backed up |
| `lab runtime` | New | Isolated upstream-only test environment |

## Gradual Customization Plan

| Priority | Customization | Rationale | When to Add |
|----------|---------------|-----------|-------------|
| P0 | SYMLINK_NAME | CLI ergonomics | After upstream tests pass |
| P0 | ollama URL | Required for local AI | After upstream tests pass |
| P0 | server.allowAnalytics | Privacy default | After upstream tests pass |
| P1 | agent.allowedTools | Security customization | After P0 validated |
| P1 | git.autoCommit | Workflow preference | After P0 validated |
| P2 | agent.privacy | Enhanced privacy | After P1 validated |
| P2 | notifications | UX preference | After P1 validated |
| P3 | color/theme | Visual preference | After P2 validated |
| P3 | Other settings | Nice-to-have | Final phase |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Upstream missing critical NixOS integration | Low | Analysis phase identifies gaps before migration |
| Lab runtime conflicts with production | Low | Isolated $OPENCODE_HOME, separate ports/config |
| Customization regression | Med | Gradual P0→P3 restoration with validation gates |
| User workflow disruption | Med | Parallel testing period, instant rollback available |
| Backup restoration failure | Low | Verified backup before any changes |

## Rollback Plan

1. **Immediate**: Restore from backup directory (~/.local/share/opencode-backup-{timestamp}/)
2. **Quick**: Switch wrapper symlink: `current/` ← `production/`
3. **Full**: Restore previous Home Manager generation: `home-manager switch --flake .#glats@{hostname} --generation N`

Rollback tested as part of Phase 0 backup verification.

## Dependencies

- Upstream opencode package builds successfully in NixOS
- Lab runtime isolation works without conflicts
- Backup/restore scripts tested

## Success Criteria

- [ ] Complete backup created and verified (Phase 0)
- [ ] Upstream-only derivation builds and runs (Phase 1)
- [ ] Analysis document identifies all NixOS-specific requirements (Phase 2)
- [ ] Lab runtime passes 1 week parallel testing (Phase 3)
- [ ] P0 customizations restored and validated (Phase 4)
- [ ] Production migration completed with zero downtime (Phase 5)
- [ ] Rollback procedure tested and documented

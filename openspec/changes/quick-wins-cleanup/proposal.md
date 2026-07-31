# Proposal: Quick Wins Cleanup

## Intent

12 low-risk Nix hygiene fixes. Zero behavior change. Rename files, delete dead code, fix comments, unify patterns.

## Scope

### In Scope
1. Rename `linux/home/webcam-rog.nix` → `webcam.nix` (used by t14 too)
2. Add comment "Disables NixOS firewall" in `linux/system/networking/firewall.nix`
3. Rename `linux/system/hardware/nvidia.nix` → align with option name
4. Delete stale `# Force rebuild` comment in `linux/system/base/home-manager.nix`
5. Delete `linux/system/features/conky/default.nix` (7-line indirection, imports options.nix only)
6. Delete redundant config block in `linux/system/features/conky/options.nix`
7. Remove hypridle from `linux/system/base/profiles/core.nix` (omarchy-only)
8. Spanish comment → English in `hosts/rog/default.nix`
9. Unify shell-gpt enable pattern across hosts
10. Delete stale OpenCode comment block in `hosts/thinkcentre/default.nix`
11. Clean nested `lib.mkIf` in `linux/system/networking/wol.nix`
12. Add `null` as explicit "no desktop" value in `linux/system/base/options.nix`

### Out of Scope
- Any behavioral change
- New features
- Host-specific policy changes

## Capabilities

### New Capabilities
None

### Modified Capabilities
None

## Approach

One commit per fix or one batch commit. Each atomic: rename, delete, comment-edit, or config-unify.

## Affected Areas

| Area | Impact | Files |
|------|--------|-------|
| `linux/home/` | Rename | webcam-rog.nix → webcam.nix |
| `linux/system/networking/` | Comment | firewall.nix, wol.nix |
| `linux/system/hardware/` | Rename | nvidia.nix |
| `linux/system/base/` | Delete dead code, add default | home-manager.nix, profiles/core.nix, options.nix |
| `linux/system/features/conky/` | Delete indirection, redundant block | default.nix, options.nix |
| `hosts/rog/` | Comment fix | default.nix |
| `hosts/thinkcentre/` | Delete stale comment | default.nix |
| `hosts/*/` | Unify pattern | shell-gpt across hosts |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Rename breaks imports | Low | Update all 3 import sites; `nix flake check` catches |
| `null` default breaks eval | Low | Test on one host first |
| hypridle removal surprises omarchy | Low | Only in profiles/core.nix; omarchy imports separately |

## Rollback Plan

`git revert` each commit. No state, no data, zero-downtime rollback.

## Dependencies

None.

## Success Criteria

- [ ] `nix flake check --no-build` passes for all hosts
- [ ] No behavioral diff in any host config
- [ ] All 12 items addressed

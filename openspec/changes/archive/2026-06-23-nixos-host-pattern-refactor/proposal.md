# Proposal: NixOS Host Pattern Refactor — Eliminate Last Host Conditional

## Intent

`home-linux/btop.nix` is the **only** remaining file in the home-manager tree that branches on `hostName`. The repository already uses a clean per-host import pattern (`hosts/{name}/home/modules.nix`). This change removes the conditional, aligns btop with the established architecture, and makes host differences explicit at the import site.

## Scope

### In Scope
- Split `home-linux/btop.nix` into a shared theme fragment and per-host config fragments.
- Remove btop from `home-linux/shared-modules.nix`.
- Add the appropriate btop import to each host's home module list.

### Out of Scope
- Changing btop settings or theme content.
- Refactoring any other modules.
- Moving existing per-host imports (conky, openfang, etc.).

## Capabilities

### New Capabilities
None.

### Modified Capabilities
None. This is a pure structural refactor with no behavioral changes.

## Approach

1. **Create `home-linux/btop-theme.nix`** — shared theme file that writes `~/.config/btop/themes/nix-colors.theme`. No conditionals.
2. **Create `home-linux/btop-file.nix`** — rog/thinkcentre variant that writes `~/.config/btop/btop.conf` via `home.file`.
3. **Create `home-linux/btop-settings.nix`** — t14 variant that sets `programs.btop.settings` (matches current `mkIf (hostName == "t14")` block).
4. **Update `home-linux/shared-modules.nix`** — remove `./btop.nix`; add `./btop-theme.nix`.
5. **Update host imports** — add `./btop-file.nix` to `hosts/rog/home/modules.nix` and `hosts/thinkcentre/home/modules.nix`; add `./btop-settings.nix` to `hosts/t14/home/omarchy.nix`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `home-linux/btop.nix` | Removed | Replaced by three focused files. |
| `home-linux/btop-theme.nix` | New | Shared color theme, zero conditionals. |
| `home-linux/btop-file.nix` | New | File-based config for rog / thinkcentre. |
| `home-linux/btop-settings.nix` | New | HM `programs.btop.settings` for t14. |
| `home-linux/shared-modules.nix` | Modified | Replace `btop.nix` with `btop-theme.nix`. |
| `hosts/rog/home/modules.nix` | Modified | Append `btop-file.nix`. |
| `hosts/thinkcentre/home/modules.nix` | Modified | Append `btop-file.nix`. |
| `hosts/t14/home/omarchy.nix` | Modified | Append `btop-settings.nix`. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Missing a setting during copy-paste | Low | Diff the generated btop configs before/after. |
| t14 omarchy override stops working | Low | Keep `lib.mkForce` usage identical. |

## Rollback Plan

Revert the commit. The original `btop.nix` is self-contained and restores all behavior in one step.

## Dependencies

None.

## Success Criteria

- [ ] `grep -r 'hostName' home-linux/` returns zero matches.
- [ ] `nix flake check --no-build` passes.
- [ ] Each host evaluates and produces the same btop config as before.

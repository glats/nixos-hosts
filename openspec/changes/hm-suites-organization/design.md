# Design: HM Suites Organization

## Technical Approach

Move MATE HM modules from flat `linux/home/` into `suites/mate/`. Aggregator `default.nix` imports submodules. Hosts opt-in; `shared-modules.nix` stops loading MATE globally.

## Architecture Decisions

### Aggregator imports submodules

**Choice**: `suites/mate/default.nix` imports 4 submodules
**Rejected**: Each host imports individually
**Why**: One import per host. New module = add to aggregator only.

### Remove MATE from shared-modules.nix

**Choice**: Delete 3 MATE imports from shared-modules
**Rejected**: Leave, just move files
**Why**: t14 uses Omarchy, never MATE.

### Fix relative paths in moved files

**Choice**: Update path strings (`../../lib` → `../../../lib`, `./chrome-app-icons` → `../../chrome-app-icons`)
**Rejected**: Move `chrome-app-icons/` dir
**Why**: One-line fix simpler than moving binary assets.

## File Changes

9 files: 5 moved, 1 created, 3 modified. See tasks.md.

Key path fixes: `mate.nix` lib ref depth +1; `chrome-apps.nix` icon ref goes up 2.

## Testing

| Layer | Command |
|-------|---------|
| Flake | `nix flake check --no-build` |
| rog | `nix build .#nixosConfigurations.rog...toplevel` |
| thinkcentre | `nix build .#nixosConfigurations.thinkcentre...toplevel` |

## Threat Matrix

N/A.

## Migration

None.
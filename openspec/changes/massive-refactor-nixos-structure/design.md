# Design: massive-refactor-nixos-structure

## Technical Approach

Replace 3-level profile chain (`base.nix` → `desktop.nix` → `server.nix`) with flat explicit imports per host. Each host's `default.nix` lists every module it uses, one per line. No transitive imports. Self-documenting.

Two-pronged rename:
- `modules/` → NixOS parts to `linux/system/`, Darwin parts absorbed into `darwin/system/` + `darwin/services/`
- `home-linux/` → `linux/home/`
- `home-darwin/` → `darwin/home/`
- Host services promoted to portable shared services under `linux/system/services/{media,web,network}/`

Fontconfig XML deduplicated into `shared/fontconfig/family-map.xml`, imported by both system `fonts.nix` and home `fontconfig.nix`.

Conky modules kept separate per host (`conky-rog.nix`, `conky-thinkcentre.nix`). Duplication is acceptable — hardware-specific values (network interfaces, mount points, sensors) differ genuinely. Attempting to merge via Nix+Lua templating risks fragile escaping bugs.

Profile files (`modules/base/profiles/*.nix`) stay at `linux/system/base/profiles/` — they're pure Nix functions returning package lists (not NixOS modules), consumed by `base/packages.nix`. No `suites/` directory needed since no DE-specific NixOS system modules exist to aggregate.

`modules/darwin/profiles/base.nix` flattened into `darwin/default.nix`.

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Import style | Flat, 1 per line, no chains | Eliminates file-jumping to trace imports. Diff shows exactly what changed |
| Module tree root | `linux/system/` not `modules/` | Platform boundary explicit. Darwin gets own root |
| Service portability | All rog services → `linux/system/services/` | Any NixOS host can import any service |
| Profile packages location | `linux/system/base/profiles/` | Pure functions consumed by packages.nix, not NixOS system modules |
| Darwin profiles base | Flattened into `darwin/default.nix` | Pure import aggregator, no inline config — one less indirection |
| Conky strategy | Keep per-host (`conky-rog.nix`, `conky-thinkcentre.nix`), no merge | Hardware differs genuinely (network, mounts, sensors). Lua+Nix merge risks fragile escaping bugs |
| mise-tools absorption | `home-darwin/mise-tools.nix` → `darwin/system/mise.nix` | mise is system-level tool, belongs with nix/homebrew not HM |
| fontconfig XML | Extracted to `shared/fontconfig/family-map.xml` | Removes 80-line XML duplication |
| rog-shutdown.nix | Keep with comment | User directive — "En pruebas, posible uso futuro" |
| opencode-theme.nix | DELETE | Orphaned, unreachable per census |
| windsurf.nix | DELETE | Commented out, orphaned, unreachable per census |
| providers-extra.nix | KEEP (reference file) | 10 providers, 412 lines — not imported but valuable reference data |
| `modules/darwin/profiles/base.nix` | DELETE | Flattened into darwin/default.nix |

## Resolved Questions

| Question | Answer | Why |
|----------|--------|-----|
| `home-linux/opencode-theme.nix` — orphaned. Delete? | **DELETE** | Census confirms NOT imported by any module. Dead code |
| `home-darwin/windsurf.nix` — commented out, orphaned. Delete? | **DELETE** | Already unreachable. Remove from filesystem |
| `home-darwin/opencode/providers-extra.nix` — not imported. Keep? | **KEEP** | Valuable reference: 10 providers, 412 lines. Move to `darwin/home/opencode/providers-extra.nix` |
| `modules/base/profiles/` — where? | **`linux/system/base/profiles/`** | Pure Nix functions returning package lists. Consumed by packages.nix co-located in base/ |
| `modules/darwin/profiles/base.nix` — flatten? | **YES (DELETE)** | Pure import aggregator. Flatten into darwin/default.nix |
| `linux/system/suites/` directory? | **REMOVE from target** | No DE-specific NixOS system modules to aggregate. Package lists at base/profiles/. HM config at linux/home/ |

## Prerequisites (critical — do first)

Before any `git mv`:

1. **Create target directories**: `linux/system/`, `darwin/system/`, `darwin/services/`
2. **Then** `git mv` subdirectories into place — moving individual subdirectories avoids the problem of `modules/` containing both Linux and Darwin code

## Complete File Changes

This table covers every file from the census (~190 entries). No orphans.

### RENAME (git mv — files move, content unchanged)

| # | From | To |
|---|------|-----|
| 1 | `modules/base/` (14 files) | `linux/system/base/` |
| 2 | `modules/base/profiles/` (8 files) | `linux/system/base/profiles/` |
| 3 | `modules/desktop/` (3 files) | `linux/system/desktop/` |
| 4 | `modules/hardware/` (6 files) | `linux/system/hardware/` |
| 5 | `modules/networking/` (4 files) | `linux/system/networking/` |
| 6 | `modules/features/` (4 files) | `linux/system/features/` |
| 7 | `modules/virtualisation/` (2 files) | `linux/system/virtualisation/` |
| 8 | `home-linux/` (27 files → 24 after windsurf delete + opencode-theme delete) | `linux/home/` |
| 9 | `home-darwin/` (22 files → 20 after mise/windsurf deletes) | `darwin/home/` |
| 10 | `hosts/rog/home/modules.nix` | `hosts/rog/home/default.nix` |
| 11 | `hosts/thinkcentre/home/modules.nix` | `hosts/thinkcentre/home/default.nix` |

### MOVE (content preserved, host-scoped → shared)

| # | From | To |
|---|------|-----|
| 12 | `hosts/rog/services/{arr-stack,jellyfin,qbittorrent,flaresolverr}.nix` | `linux/system/services/media/` |
| 13 | `hosts/rog/services/{nginx,authelia,seerr,dozzle,fileshelter,code-server,wetty,cobalt,droppy}.nix` | `linux/system/services/web/` |
| 14 | `hosts/rog/services/{wireguard,ddclient,samba,ftp,guacamole,gonic,ollama}.nix` | `linux/system/services/network/` |
| 15 | `hosts/thinkcentre/services/maquilinux-mounts.nix` | `linux/system/services/maquilinux-mounts.nix` |
| 16 | `modules/darwin/system/` (5 files) | `darwin/system/` |
| 17 | `modules/darwin/services/wsdd.nix` | `darwin/services/wsdd.nix` |
| 18 | `modules/features/services/` (3 files) | `linux/system/services/` |

### CREATE (new files)

| # | File | Content |
|---|------|---------|
| 19 | `shared/fontconfig/family-map.xml` | Extracted XML from fonts.nix + fontconfig.nix |

### DELETE

| # | File | Reason |
|---|------|--------|
| 20 | `modules/profiles/base.nix` | Eliminated import chain |
| 21 | `modules/profiles/desktop.nix` | Eliminated import chain |
| 22 | `modules/profiles/server.nix` | Eliminated import chain |
| 23 | `modules/darwin/profiles/base.nix` | Flattened into darwin/default.nix |
| 24 | `home-darwin/mise-tools.nix` | Absorbed into darwin/system/mise.nix |
| 25 | `home-linux/opencode-theme.nix` | Orphaned, unreachable (census confirms no imports) |
| 26 | `home-darwin/windsurf.nix` | Orphaned, commented out (census confirms no imports) |

### MODIFY (content changes, paths updated)

| # | File | Change |
|---|------|--------|
| 27 | `flake.nix` | Update all path refs: `home-linux/` → `linux/home/`, `home-darwin/` → `darwin/home/`. Update `linuxHomeModules`/`darwinHomeModules` let bindings |
| 28 | `hosts/rog/default.nix` | Replace `modules/profiles/server.nix` with flat import list (see manifest below). Update all module paths |
| 29 | `hosts/thinkcentre/default.nix` | Replace `modules/profiles/server.nix` with flat import list. Update paths |
| 30 | `hosts/t14/default.nix` | Update module paths `../../modules/` → `../../linux/system/` |
| 31 | `darwin/default.nix` | Replace `modules/darwin/profiles/base.nix` with flat imports. Update HM path `./home-darwin` → `./home` |
| 32 | `lib/mkHost.nix` | No change (imports `../hosts/${hostname}` still valid) |
| 33 | `lib/mkDarwinHost.nix` | No change (imports `../darwin` still valid) |
| 34 | `linux/system/base/home-manager.nix` | Update host home path: `../../hosts/${hostname}/home/modules.nix` → `../../../hosts/${hostname}/home/default.nix` |
| 35 | `linux/home/shared-modules.nix` | Update `../shared/` → `../../shared/` (5 files). Conky modules remain unchanged |
| 36 | `darwin/home/shared-modules.nix` | Update `../shared/` → `../../shared/` (5 files). Remove `./mise-tools.nix`. Remove `#./windsurf.nix` comment |
| 37 | `darwin/home/default.nix` | (same dir, relative imports unchanged after rename) |
| 38 | `linux/system/desktop/fonts.nix` | Import XML from `../../../shared/fontconfig/family-map.xml` instead of inline |
| 39 | `linux/home/fontconfig.nix` | Import XML from `../../shared/fontconfig/family-map.xml` instead of inline |
| 40 | `darwin/system/mise.nix` | Absorb home-darwin/mise-tools.nix HM-level config into system module |
| 41 | `hosts/rog/home/default.nix` (was modules.nix) | Update path refs. Conky, openfang, webcam, mate-rog-autostart imports keep same filenames, paths updated |
| 42 | `hosts/thinkcentre/home/default.nix` (was modules.nix) | Update path refs. Conky import keeps same filename, path updated |
| 43 | `hosts/t14/home/omarchy.nix` | Update `home-linux/*` → `linux/home/*` imports. Update `shared/*` → `../../shared/*` paths |
| 44 | `hosts/t14/home/default.nix` | Update `home-linux/*` → `linux/home/*` imports |
| 45 | All `linux/home/*.nix` with `../shared/` refs | Update `../shared/` → `../../shared/` (ghostty.nix, git.nix, gpg.nix, superfile.nix, tmux.nix, theme.nix) |
| 46 | All `darwin/home/*.nix` with `../shared/` refs | Update `../shared/` → `../../shared/` (ghostty.nix, git.nix, gpg.nix, superfile.nix, tmux.nix, theme.nix, sops.nix) |
| 47 | `linux/home/mate.nix` | Update `import ../lib/colors.nix` → `import ../../lib/colors.nix` |

### KEEP (no change)

All remaining files from census: `lib/` (4), `shared/` (12), `shared/opencode/` (7), `overlays/` (2), `pkgs/` (17), `hosts/mact2/default.nix`, `hosts/*/secrets.nix` (3), `hosts/*/conky-config.nix` (2), `hosts/*/hardware-configuration.nix` (3), `hosts/t14/home/omarchy.nix` (modified paths only), `hosts/t14/home/hypr/` (5), `hosts/t14/home/mouse-wiggle.nix`

## Host Import Manifests

### rog/default.nix (after)

```nix
imports = [
  ./hardware-configuration.nix
  ./secrets.nix
  ./conky-config.nix

  # Base system
  ../../linux/system/base/cachix.nix
  ../../linux/system/base/nix.nix
  ../../linux/system/base/users.nix
  ../../linux/system/base/zsh.nix
  ../../linux/system/base/sops.nix
  ../../linux/system/base/polkit.nix
  ../../linux/system/base/logind.nix
  ../../linux/system/base/nh.nix
  ../../linux/system/base/dconf.nix
  ../../linux/system/base/options.nix
  ../../linux/system/base/packages.nix
  ../../linux/system/base/home-manager.nix
  ../../linux/system/base/shutdown-fix.nix
  ../../linux/system/base/shutdown-debug.nix

  # Desktop
  ../../linux/system/desktop/fonts.nix
  ../../linux/system/desktop/i18n.nix
  ../../linux/system/desktop/kmscon.nix

  # Hardware
  ../../linux/system/hardware/nvidia.nix
  ../../linux/system/hardware/keyring.nix
  ../../linux/system/hardware/asus-fan-control.nix
  ../../linux/system/hardware/rog-shutdown.nix          # KEPT — en pruebas, posible uso futuro
  ../../linux/system/hardware/rog-poweroff-workaround.nix

  # Networking
  ../../linux/system/networking/openssh.nix
  ../../linux/system/networking/firewall.nix
  ../../linux/system/networking/avahi.nix
  ../../linux/system/networking/wol.nix

  # Features
  ../../linux/system/features/boot.nix
  ../../linux/system/features/conky

  # Services — shared
  ../../linux/system/services/xrdp.nix
  ../../linux/system/services/github-mcp-server.nix
  ../../linux/system/services/github-token-check.nix

  # Services — media
  ../../linux/system/services/media/arr-stack.nix
  ../../linux/system/services/media/jellyfin.nix
  ../../linux/system/services/media/qbittorrent.nix
  ../../linux/system/services/media/flaresolverr.nix

  # Services — web
  ../../linux/system/services/web/nginx.nix
  ../../linux/system/services/web/authelia.nix
  ../../linux/system/services/web/seerr.nix
  ../../linux/system/services/web/dozzle.nix
  ../../linux/system/services/web/fileshelter.nix
  ../../linux/system/services/web/code-server.nix
  ../../linux/system/services/web/wetty.nix
  ../../linux/system/services/web/cobalt.nix
  ../../linux/system/services/web/droppy.nix

  # Services — network
  ../../linux/system/services/network/wireguard.nix
  ../../linux/system/services/network/ddclient.nix
  ../../linux/system/services/network/samba.nix
  ../../linux/system/services/network/ftp.nix
  ../../linux/system/services/network/guacamole.nix
  ../../linux/system/services/network/gonic.nix
  ../../linux/system/services/network/ollama.nix

  # Virtualisation
  ../../linux/system/virtualisation/libvirt.nix
  ../../linux/system/virtualisation/docker.nix
];
```

### thinkcentre/default.nix (after)

```nix
imports = [
  ./hardware-configuration.nix
  ./secrets.nix
  ./conky-config.nix

  # Base system (all 14)
  ../../linux/system/base/cachix.nix
  ../../linux/system/base/nix.nix
  ../../linux/system/base/users.nix
  ../../linux/system/base/zsh.nix
  ../../linux/system/base/sops.nix
  ../../linux/system/base/polkit.nix
  ../../linux/system/base/logind.nix
  ../../linux/system/base/nh.nix
  ../../linux/system/base/dconf.nix
  ../../linux/system/base/options.nix
  ../../linux/system/base/packages.nix
  ../../linux/system/base/home-manager.nix
  ../../linux/system/base/shutdown-fix.nix

  # Desktop (all 3)
  ../../linux/system/desktop/fonts.nix
  ../../linux/system/desktop/i18n.nix
  ../../linux/system/desktop/kmscon.nix

  # Hardware (keyring only)
  ../../linux/system/hardware/keyring.nix

  # Networking (all 4)
  ../../linux/system/networking/openssh.nix
  ../../linux/system/networking/firewall.nix
  ../../linux/system/networking/avahi.nix
  ../../linux/system/networking/wol.nix

  # Features
  ../../linux/system/features/boot.nix
  ../../linux/system/features/conky

  # Services
  ../../linux/system/services/xrdp.nix
  ../../linux/system/services/github-mcp-server.nix
  ../../linux/system/services/github-token-check.nix
  ../../linux/system/services/maquilinux-mounts.nix

  # Virtualisation
  ../../linux/system/virtualisation/docker.nix
];
```

### t14/default.nix (after)

t14 already uses flat imports (no profile chain). Changes: path prefix `../../modules/` → `../../linux/system/`.

```nix
imports = [
  ./hardware-configuration.nix
  ./secrets.nix

  # Base (8 individual — rog/thinkcentre base minus MATE-specific + unused)
  ../../linux/system/base/cachix.nix
  ../../linux/system/base/nix.nix
  ../../linux/system/base/users.nix
  ../../linux/system/base/zsh.nix
  ../../linux/system/base/sops.nix
  ../../linux/system/base/polkit.nix
  ../../linux/system/base/options.nix
  ../../linux/system/base/packages.nix

  # Desktop
  ../../linux/system/desktop/fonts.nix
  ../../linux/system/desktop/i18n.nix
  ../../linux/system/desktop/kmscon.nix

  # Hardware
  ../../linux/system/hardware/amd-laptop.nix
  ../../linux/system/hardware/keyring.nix

  # Networking
  ../../linux/system/networking/openssh.nix

  # Features
  ../../linux/system/features/boot.nix

  # Services
  ../../linux/system/services/github-mcp-server.nix
  ../../linux/system/services/github-token-check.nix

  # Virtualisation
  ../../linux/system/virtualisation/docker.nix

  # Home Manager (omarchy)
  ./home/omarchy.nix
  inputs.hyprdynamicmonitors.homeManagerModules.default
];
```

Note: t14 does NOT import `logind.nix`, `nh.nix`, `dconf.nix`, `home-manager.nix`, `shutdown-fix.nix`, `avahi.nix`, `firewall.nix`, `wol.nix` — these are handled by omarchy-nix or not needed on t14.

### mact2/default.nix

Unchanged (16 lines, hostname only).

### darwin/default.nix (after)

```nix
imports = [
  # Flattened from modules/darwin/profiles/base.nix
  ./system/nix.nix
  ./system/cachix.nix
  ./system/homebrew.nix
  ./system/settings.nix
  ./system/mise.nix
  ./services/wsdd.nix

  # Home Manager (path updated from ./home-darwin)
  inputs.home-manager.darwinModules.home-manager
  inputs.nix-homebrew.darwinModules.nix-homebrew
  ./home
];

# ...rest unchanged (user config, environment, services)
```

## Target Tree (final structure)

```
linux/
  system/
    base/           ← nix, users, zsh, sops, cachix, polkit, logind, nh, options, dconf, packages, shutdown-fix, shutdown-debug, home-manager
      profiles/     ← core.nix, dev.nix, media.nix, virt.nix, browsers.nix, mate.nix, gnome.nix, cli-extra.nix
    desktop/        ← fonts.nix, i18n.nix, kmscon.nix
    hardware/       ← nvidia.nix, amd-laptop.nix, asus-fan-control.nix, keyring.nix, rog-poweroff-workaround.nix, rog-shutdown.nix
    networking/     ← openssh.nix, firewall.nix, avahi.nix, wol.nix
    features/       ← boot.nix
      conky/        ← default.nix, options.nix
    services/       ← xrdp.nix, github-mcp-server.nix, github-token-check.nix, maquilinux-mounts.nix
      media/        ← arr-stack.nix, jellyfin.nix, qbittorrent.nix, flaresolverr.nix
      web/          ← nginx.nix, authelia.nix, seerr.nix, dozzle.nix, fileshelter.nix, code-server.nix, wetty.nix, cobalt.nix, droppy.nix
      network/      ← wireguard.nix, ddclient.nix, samba.nix, ftp.nix, guacamole.nix, gonic.nix, ollama.nix
    virtualisation/ ← docker.nix, libvirt.nix
  home/             ← all home-linux/ modules
    conky-rog.nix       ← per-host conky (KEPT separate)
    conky-thinkcentre.nix  ← per-host conky (KEPT separate)
    shared-modules.nix ← updated paths

darwin/
  system/           ← nix.nix, cachix.nix, homebrew.nix, settings.nix, mise.nix
    mise.nix        ← UNIFIED: absorbs home-darwin/mise-tools.nix
  services/         ← wsdd.nix
  home/             ← all home-darwin/ modules (19 files + opencode/ subdir)
    opencode/
      providers-extra.nix  ← KEPT (reference file, not imported)
      mcps-extra.nix       ← (unchanged, imported by default.nix)
    remote-desktop.nix     ← Darwin RDP/VNC launchers
    spotlight-index.nix    ← Spotlight index config
    ssh.nix                ← Darwin SSH config
    vscode.nix             ← VS Code extensions
    shared-modules.nix     ← updated paths, no mise-tools
  default.nix        ← entry point, flattened imports

shared/              ← unchanged (palette, tool configs, AI stack, rules/)
  fontconfig/
    family-map.xml   ← NEW extracted XML

hosts/
  rog/default.nix    ← FLAT imports (all 50+ modules listed)
  rog/home/default.nix  ← renamed from modules.nix
  thinkcentre/default.nix
  thinkcentre/home/default.nix
  t14/default.nix    ← FLAT imports, path updates
  t14/home/omarchy.nix   ← stays, path updates
  mact2/default.nix  ← stays minimal
```

## Migration Plan

13 steps, each reversible via `git checkout` of individual files or full `git reset --hard`.

| Step | Action | Verify |
|------|--------|--------|
| 1 | `git checkout -b refactor/nixos-flat-structure` | Clean branch |
| 2 | Create target dirs: `linux/system/`, `darwin/system/`, `darwin/services/`, `shared/fontconfig/` | `ls -d linux/system darwin/system darwin/services shared/fontconfig` |
| 3 | `git mv modules/base/ linux/system/base/` etc. — **individual subdir moves** (NOT single `modules/` mv since it contains darwin too) | `git status` shows renames |
| 4 | `git mv modules/darwin/system/ darwin/system/` ; `git mv modules/darwin/services/ darwin/services/` | Darwin parts extracted |
| 5 | `git mv modules/features/services/ linux/system/services/` ; `git mv modules/features/ linux/system/features/` ; `git mv modules/desktop/ linux/system/desktop/` ; `git mv modules/hardware/ linux/system/hardware/` ; `git mv modules/networking/ linux/system/networking/` ; `git mv modules/virtualisation/ linux/system/virtualisation/` | All NixOS modules moved |
| 6 | `git mv home-linux/ linux/home/` ; `git mv home-darwin/ darwin/home/` | Home Manager directories renamed |
| 7 | Delete empty dirs: `modules/profiles/`, `modules/darwin/profiles/`, empty `modules/` stub | `git status` shows deletes |
| 8 | Create service subdirs: `linux/system/services/{media,web,network}/` ; `git mv hosts/rog/services/` into them by category. `git mv hosts/thinkcentre/services/maquilinux-mounts.nix linux/system/services/` | Services moved, `hosts/rog/services/` empty |
| 9 | Create `shared/fontconfig/family-map.xml` (extracted XML). Update `fonts.nix` + `fontconfig.nix` to import it | XML content matches original inline blocks |
| 10 | Delete orphaned: `opencode-theme.nix`, `windsurf.nix`. Delete `mise-tools.nix` (absorbed into `darwin/system/mise.nix`). Conky files stay per host (not merged) | Files exist/absent as expected |
| 11 | Rewrite host `default.nix` files with flat imports (see manifests above) | Visual review, cross-ref with census REACH |
| 12 | Update all path references: flake.nix, home-manager.nix, shared-modules.nix (both), t14 omarchy/default, darwin/default.nix, all `../shared/` → `../../shared/` fixes | `nix flake check --no-build` |
| 13 | `format-nix && nix flake check --no-build` | Exit 0 for all hosts |

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Build | All 4 hosts | `nix flake check --no-build` validates rog, thinkcentre, t14. Separately build mact2 |
| Syntax | All .nix files | `format-nix` then `git diff --stat` — no formatting changes = no syntax errors |
| HM standalone | rog, thinkcentre, t14, mact2 | `home-manager build --flake .#{host}` |
| Import integrity | No orphan imports | `rg "modules/"` should return 0 results after rename |
| Census coverage | All 190 files accounted | Cross-ref design tables with census sections |
| Path consistency | All imports resolve | `nix flake check` catches broken paths. Check depth-aware: `linux/home/` is 2 dirs deep (not 1 like `home-linux/`) |

## Path Depth Reference

After rename, module trees are one level deeper than before:

| Location | Depth from root | `../shared/` needs |
|----------|----------------|-------------------|
| `home-linux/` (before) | 1 | `../shared/` |
| `linux/home/` (after) | 2 | `../../shared/` |
| `home-darwin/` (before) | 1 | `../shared/` |
| `darwin/home/` (after) | 2 | `../../shared/` |
| `modules/base/` (before) | 2 | (N/A — no shared refs) |
| `linux/system/base/` (after) | 3 | `../../../shared/` |

Files affected by the depth change:
- All `linux/home/` files with `../shared/` imports (ghostty, git, gpg, superfile, tmux, theme, shared-modules)
- All `darwin/home/` files with `../shared/` imports (ghostty, git, gpg, superfile, tmux, theme, sops, shared-modules)
- `linux/home/mate.nix`: `import ../lib/colors.nix` → `import ../../lib/colors.nix`
- `linux/system/base/home-manager.nix`: `../../hosts/` → `../../../hosts/`
- `linux/system/desktop/fonts.nix`: inline XML → `../../../shared/fontconfig/family-map.xml`
- `hosts/t14/home/omarchy.nix`: `home-linux/` → `linux/home/` imports

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| Path depth errors | Step 12 specifically checks all `../shared/` refs. `nix flake check` catches broken imports |
| Missing import during flattening | Host manifests cross-referenced with census. Every module rog/thinkcentre/t14 imports listed explicitly |
| Conky merge breaks host-specific config | Merged module uses `conkyConfig` specialArg (already flowing through extraSpecialArgs). No behavior change |
| Darwin mise duplication | HM mise-tools.nix absorbed into darwin/system/mise.nix. Delete HM file to prevent confusion |
| Orphan detection | All files from census appear in one of: RENAME, MOVE, CREATE, DELETE, MODIFY, KEEP tables. No unaccounted files |
| Suites (D3) | Deferred to future iteration. Current change focuses on structural rename + profile chain elimination. HM suite modules (mate.nix, rofi.nix, picom.nix, etc.) stay flat in `linux/home/` for now |

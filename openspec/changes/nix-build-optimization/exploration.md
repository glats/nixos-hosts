# Exploration: NixOS Build Optimization

**Change**: `nix-build-optimization`
**Date**: 2026-06-26
**Mode**: Automático (no user gate)
**Artifact store**: Híbrido (this file + Engram topic)
**Scope**: 3 NixOS hosts (rog, thinkcentre, t14) + 1 Darwin (mact2) on a unified flake with home-manager + sops-nix.

---

## 1. Problem Statement

User reports that `nixos-rebuild switch` and `nixos-build` (which wraps `nixos-rebuild`) frequently trigger extensive rebuilds, even for small config changes. The pain is real: builds that should take seconds (no derivation should change) end up taking minutes-to-hours, and the laptop freezes due to OOMs / CPU saturation.

The investigation has two parts:
- **External**: what the wider NixOS ecosystem does to keep rebuilds small.
- **Local**: what this repo already does, what's missing, and which knobs are mis-set.

---

## 2. What Causes Large Rebuilds (root causes from the literature)

A "rebuild" happens whenever a derivation's store path hash changes. The hash depends on all inputs — nixpkgs commit, dependency package hashes, build flags, env vars, config bits. A small change in any of these propagates through the entire dependency closure, so:

1. **nixpkgs updates** — `inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"` is a *branch*; every `nix flake update` (or every 6 h Hydra eval) moves it forward, and the moved commit often touches one of the 100+ "stage next" packages (glibc, gcc, python, openssl, linux kernel headers, …), forcing the entire world to rebuild. (Tweag, siraben, UlyssesZh posts)
2. **Overlay/override scope** — overriding `libbluray` rebuilds `ffmpeg` and every package that depends on ffmpeg. Overriding `xdg-desktop-portal` rebuilds anything linking against it. Overriding a `linuxPackages_zen.kernel` rebuilds the kernel and every kernel module. (Discourse #65657, UlyssesZh article)
3. **Missing binary cache** — packages not in `cache.nixos.org` fall back to local build. Most custom packages here (`opencode`, `engram`, `gentle-ai`, `asus-fan-control`, `pipewire-module-xrdp`, the t14 `xdg-desktop-portal` patch) are not on any official cache.
4. **Garbage collection stripping build outputs** — by default `keep-outputs = false` and `keep-derivations = true`. After `nix-collect-garbage`, all build-time outputs of any root are deleted, so the next rebuild of even the *same* derivation re-runs every step. (Discourse #31081, nix.conf(5))
5. **Oversubscribed parallelism** — `max-jobs = auto` (NixOS default) and `cores = 0` mean *every CPU core runs a derivation, and every derivation can use all cores*. On a 16-core box that's 256 parallel compiler instances. Tied for OOMs and slow rebuilds, and on an interactive desktop the system becomes unusable. (NixOS/nixpkgs #198668)
6. **Module re-evaluation** — `nixos-rebuild` re-evaluates all ~1100+ module `enable` options on every invocation. With the legacy bash `nixos-rebuild` this dominates wall-time for no-op rebuilds. The Python rewrite `nixos-rebuild-ng` is faster and will be default in 25.11. (nixpkgs #57477, nixos-rebuild-ng)
7. **HTTP/2 stalls + thin caches** — `cache.nixos.org` is served by a single S3-backed CDN. With a slow network, downloads stall for 5+ minutes per file. `http-connections = 50` and `stalled-download-timeout = 30` help; mirrors help more.

---

## 3. External Research (exa + GitHub)

### 3.1 Binary caches / substituters

The most-cited optimization. `nix.settings.substituters` plus `nix.settings.trusted-public-keys` (verified via NixOS MCP option search: both options exist on the nix.settings submodule, type `list of string`).

Common patterns found in 30+ public repos:
- `cache.nixos.org` (official, hydra-built, but slow) + `nix-community.cachix.org` (community, fast, post-built) — appears in ~100% of public configs.
- `nixpkgs.cachix.org` (covers most nixpkgs) — appears in ~30% of configs.
- `hyprland.cachix.org`, `ghostty.cachix.org`, `numtide.cachix.org` — niche caches for specific packages.
- `flakehub.com/cache` (Determinate) — newer commercial cache.
- Priority trick: `?priority=N` URL param to bias cache ordering.

The discourse thread "Nixos-rebuild triggers enormous rebuilds" (#78481) and the siraben "Dirty Nix flake hacks" post both note that **adding many caches adds per-query HTTP latency**, so don't pile on caches you don't actively use.

### 3.2 Build parallelism (`cores`, `max-jobs`)

NixOS defaults:
- `max-jobs = "auto"` (NixOS module default since 23.11) — runs as many local jobs as CPU cores.
- `cores = 0` — each derivation uses all CPU cores.

This is the worst combination. NixOS/nixpkgs #198668 documents that the upstream Nix default is `max-jobs = 1`, and that `auto` "will often lead to OOMs on systems with many cores." 24-core box running 24 jobs × 24 cores = 576 processes. Reddit/discourse users report:
- `cores = 0, max-jobs = 1` — conservative, predictable.
- `cores = 0, max-jobs = N/2` — common for power-user boxes.
- `cores = 2, max-jobs = N/2` — best for RAM-constrained boxes (8-16 GB).
- `cores = 0, max-jobs = 0` — local build disabled, use remote builders / substituters only.

The `nix.settings.cores` option is verified to exist via nixos MCP: *"signed integer — This option defines the maximum number of concurrent tasks during one build … 0 means … use all available CPU cores."*

### 3.3 Keep outputs and keep derivations

`nix.settings.keep-outputs = true` + `nix.settings.keep-derivations = true` are the canonical "developer friendly" settings. They:
- Prevent `nix-collect-garbage` from deleting build outputs needed to re-run an already-built derivation.
- Prevent the .drv files from being deleted, so `nix-store --query` is useful for debugging.
- Cost: more disk usage (~30% in some cases, per Discourse #31081).

The pattern is present in `nix.conf(5)` examples and in 30+ of the searched repos (`mitchellh/nixos-config`, `notusknot/dotfiles-nix`, `msfjarvis/dotfiles`, `marmos91/dotfiles`, etc.).

### 3.4 Pinning nixpkgs by commit

The biggest single win for "small rebuilds" per siraben, Tweag, nix.dev, and the channel-to-flakes guide. The current flake uses `nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"`, which is a **moving branch** that gets new commits every few hours. Each `nix flake update` lands a fresh commit and may pull a "rebuild-the-world" change with it.

Two strategies:
- **Pin to a tested commit**: `nixpkgs.url = "github:NixOS/nixpkgs/abcdef1234567890..."` — only changes when you explicitly update the URL. Combined with a separate "tracking" branch that bumps the commit, this is a manual but predictable cadence.
- **Pin to a stable branch**: `nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05"` — only updated by upstream when 25.05.x is bumped, with backports.

Trade-off: less bleeding-edge, more predictable rebuilds. For 3 hosts and a 1-user setup, the predictability win >> the newness loss.

### 3.5 `inputs.X.inputs.nixpkgs.follows = "nixpkgs"`

This repo **already does this** for most inputs (home-manager, sops-nix, omarchy-nix, nixos-hardware, opencode-src, nix-darwin, determinate, nix-vscode-extensions, ghostty). Good. Farid Zakaria's blog notes that "It's faster … it's less correct since we are deviating from what the authors of the flake desired," but the speed/evaluation-graph win is large.

Some inputs are *not* `follows`-aligned (e.g. `nix-colors`, `gentle-ai-src`, `engram-src`, `caveman-src`, `sub-agent-statusline`, `asus-fan-control-src`, `pipewire-module-xrdp-src`, `homebrew-brew`, `nix-homebrew`). Of these:
- `gentle-ai-src`, `engram-src`, `caveman-src`, `sub-agent-statusline` are `flake = false` (raw sources only) — nixpkgs follows are N/A.
- `nix-colors` is a flake, but its input set is not visible in this file; it may pull its own nixpkgs.

### 3.6 NH (nix helper)

`nix-community/nh` is a Rust reimplementation of `nixos-rebuild` / `home-manager switch` / `darwin-rebuild`. Already configured in this repo at `modules/base/nh.nix`. Quoting the docs:
> "Shows a pretty diff thanks to nvd of the rebuild transaction … Includes a handy --ask flag, to check the changes before committing … Gets around some problems around specialisations."

The repo's `bin/nixos-build` script wraps `nixos-rebuild` directly, NOT `nh os`. Switching the wrapper to `nh` would give a built-in `--ask` (review changes before activating) and a built-in diff of what services would be restarted. This is a low-risk, medium-value change.

### 3.7 Determinate Nix

The `determinate` input is **imported in the flake** (line 84-88) but **not actually used** — the system still runs upstream Nix. Determinate Nix provides:
- **Lazy Trees** (3.5.2+): 3× faster evaluation, 20× less disk for monorepos.
- **Multithreaded evaluation**: 50%+ faster for many ops.
- **Stable flakes** (no `nix-command flakes` experimental features).
- **Auto certificate, automatic GC**.

This is the largest single performance win if the user is willing to swap their system Nix for Determinate Nix. The flake input is already there, so the path is paved. Caveats:
- Determinate is a downstream fork — not all `nix.*` options are 1:1.
- The repo's `bin/nixos-build` is upstream-Nix-friendly, so any switch must be made consciously.

### 3.8 Overlays and patches

The t14 host has a custom overlay (lines 83-91) that patches `xdg-desktop-portal` with a hand-rolled patch. Per Discourse #65657, this is a textbook "force a rebuild" overlay. If upstream NixOS eventually accepts a similar fix, the patch becomes unnecessary. A periodic review of custom overlays (every few months) is a good practice.

The `linux.nix` overlay has 4 minor package tweaks (`linuxPackages_zen`, `symbola`, `libmateweather`) that touch stable APIs and rarely cause cascading rebuilds. Low risk.

### 3.9 Build script (`bin/nixos-build`)

The wrapper does NOT pass any build flags. It just runs `sudo nixos-rebuild switch --flake "$FLAKE_PATH#$HOSTNAME"`. Adding flags like `--option keep-going true` (continue past errors) and `--option show-trace true` (better error messages) would help, but neither directly reduces build time.

---

## 4. Local Investigation — What This Repo Already Does

| Knob | Current state | Reference |
|------|--------------|-----------|
| `nix.settings.substituters` | `mkBefore`: aseipp fastly mirrors (IPv6 + HTTP/2-capable). `mkAfter` (via `cachix.nix`): cache.nixos.org, nix-community, ghostty, nixpkgs-unfree, flox, nixpkgs. | `modules/base/nix.nix` + `modules/base/cachix.nix` |
| `nix.settings.trusted-public-keys` | Yes (cache.nixos.org, nix-community, ghostty, nixpkgs-unfree, flox, nixpkgs). | `modules/base/cachix.nix` |
| `nix.settings.trusted-substituters` | **NOT SET** (defaults to the same list as `substituters` only for root). | — |
| `nix.settings.auto-optimise-store` | `true` ✓ | `modules/base/nix.nix` |
| `nix.settings.experimental-features` | `nix-command flakes` ✓ | `modules/base/nix.nix` |
| `nix.settings.cores` | **NOT SET** (NixOS default = 0 = all cores) | — |
| `nix.settings.max-jobs` | **NOT SET** (NixOS default = "auto" = N cores) | — |
| `nix.settings.keep-outputs` | **NOT SET** (default = false; outputs GC'd) | — |
| `nix.settings.keep-derivations` | **NOT SET** (default = true; OK) | — |
| `nix.settings.http-connections` | `50` (default 25) ✓ | `modules/base/nix.nix` |
| `nix.settings.stalled-download-timeout` | `30` (default 300) ✓ | `modules/base/nix.nix` |
| `nix.settings.download-attempts` | `10` (default 5) ✓ | `modules/base/nix.nix` |
| `nix.settings.connect-timeout` | `15` ✓ | `modules/base/nix.nix` |
| `nix.settings.http2` | `false` (workaround for fastly + curl bug) ✓ | `modules/base/nix.nix` |
| `nix.gc.automatic` | `false` ✓ (manual GC only) | `modules/base/nix.nix` |
| `nix.distributedBuilds` | **NOT SET** (no remote builders) | — |
| `inputs.nixpkgs.url` | `github:NixOS/nixpkgs/nixos-unstable` (branch) | `flake.nix` |
| `inputs.X.inputs.nixpkgs.follows` | Set for most flake inputs ✓ | `flake.nix` |
| `programs.nh.enable` | Imported (`modules/base/nh.nix`) but `bin/nixos-build` doesn't use it | `modules/base/nh.nix` |
| Custom overlays | linux.nix (4 tweaks), t14-specific xdg-desktop-portal patch | `overlays/linux.nix`, `hosts/t14/default.nix` |
| Cachix tooling | `pkgs.cachix` installed system-wide ✓ | `modules/base/cachix.nix` |
| Darwin cachix | Separate `darwin/cachix.nix` with only 3 caches (less coverage than linux side) | `darwin/cachix.nix` |

**Identified gaps:**
1. No bounded `max-jobs` / `cores` → OOM-prone on big boxes; the source of "the laptop freezes during builds."
2. No `keep-outputs = true` → every GC forces a full rebuild of any re-built package.
3. No `nix.registry.nixpkgs.flake = nixpkgs` → `nix shell nixpkgs#foo` fetches the latest nixos-unstable instead of the locked version, causing the user to download a fresh tree every time.
4. nixpkgs is pinned to a branch, not a commit → no manual control over mass-rebuild-causing updates.
5. `bin/nixos-build` doesn't use `nh`, missing the `--ask` / diff features.
6. `darwin/cachix.nix` is missing the aseipp fastly mirrors and nixpkgs/flox caches that the linux side has → mact2 build is slower.
7. The t14 custom overlay for xdg-desktop-portal forces every t14 build to compile xdg-desktop-portal from source. Once upstream NixOS has a fix, this can be removed.

---

## 5. Catalog of Mitigations (ranked by ROI)

### Tier 1 — Cheap, high impact (recommended for the next change)

| Mitigation | Cost | Benefit | Risk |
|------------|------|---------|------|
| Set `nix.settings.max-jobs = lib.mkDefault 1` and `nix.settings.cores = 0` | tiny .nix edit | Stops OOMs; predictable build time; laptop stays responsive | Slower wall-time for single big jobs (e.g. 7h → 8h) |
| Add `nix.settings.keep-outputs = true` (and confirm `keep-derivations = true`) | tiny .nix edit | Next rebuild of an already-built package = 0 compile | ~30% more disk in /nix/store |
| Add `nix.settings.trusted-substituters` mirroring `substituters` (for non-root users) | tiny .nix edit | Home-manager `switch` and `nix profile` use the same fast caches | nil |
| Sync `darwin/cachix.nix` to use the same fastly mirrors + full cachix list | tiny .nix edit | mact2 catches up to linux build speed | nil |
| Wire `bin/nixos-build` to use `nh os` for switch/test/boot, keep `nixos-rebuild` for direct advanced cases | medium .nix + .sh edit | Built-in `--ask` previews service restarts; fewer "oops" rebuilds | nh is younger than nixos-rebuild; rare edge cases |

### Tier 2 — Medium cost, high impact

| Mitigation | Cost | Benefit | Risk |
|------------|------|---------|------|
| Pin `inputs.nixpkgs.url` to a known-good commit (e.g. the commit from `nixos-unstable` 3-7 days ago) | flake.nix edit + commit | Drastically reduces "random mass rebuild" on `nix flake update`; user controls cadence | Loses bleeding-edge; manual step |
| Add a `flake.lock` "fast-forward" workflow — a helper that bumps nixpkgs only after a CI/Hydra check | New script in `bin/` | Catches mass-rebuild-causing commits before they land on your machines | Complex; needs CI |
| Remove t14's xdg-desktop-portal overlay once upstream has the fix | small .nix edit when upstream fixes | t14 build no longer rebuilds xdg-desktop-portal and its 100+ reverse deps | Upstream may never fix; track issue |

### Tier 3 — Higher cost, situational

| Mitigation | Cost | Benefit | Risk |
|------------|------|---------|------|
| Switch to Determinate Nix (the `determinate` input is already in `flake.nix`) | OS-level install + config audit | Lazy trees 3× eval / 20× disk; multithreaded eval; stable flakes | Downstream Nix; some nix.settings keys differ; significant change |
| Set up a remote builder (another host, e.g. rog as a build server for t14) | SSH key + nix config | Offload heavy builds off the laptop | Hardware must be on; SSH key management |
| `cachix push` of local custom packages (opencode, engram, gentle-ai, asus-fan-control, pipewire-module-xrdp, xdg-desktop-portal patched, …) so they survive a clean install | Cachix account + push script in CI | Even a freshly-provisioned host skips local builds of these | Operational overhead |
| Run an in-cluster `nix-serve` (http binary cache) on rog for the other hosts | New service in `hosts/rog/services/` | LAN-speed binary pulls (no internet) | Host uptime dependency |
| Audit / reduce custom overlay surface | Ongoing | Less surface for accidental rebuilds | May break user-visible customizations |

### Tier 4 — Out of scope for this change (good to know)

- Content-addressed Nix (CA-Nix / git+lfs): not yet stable, very large change.
- NixOS module rewrite for faster eval: upstream effort, not user-controllable.
- `nixos-rebuild-ng` (Python rewrite, default in 25.11): wait for NixOS upstream.

---

## 6. Anti-patterns observed (for the apply/spec phase to avoid)

- **Per the Discourse advice**: don't add caches you don't need. The current 5 cachix + 2 aseipp mirrors are reasonable; resist adding more.
- **The siraben `--override-input` hack** (override nixpkgs to skip rebuild) is **not recommended** for this repo — it silently breaks reproducibility.
- **Pinning to a different `nixpkgs-stable` per host** is a more advanced strategy than this repo needs; the 3 hosts are similar enough that one pin is fine.

---

## 7. Recommended Scope for `propose` Phase

A reasonable first cut of the proposal (subject to user approval):
1. Add `nix.settings.cores = 0; nix.settings.max-jobs = lib.mkDefault 1;` to `modules/base/nix.nix` (or split into a new `modules/base/build-parallelism.nix`).
2. Add `nix.settings.keep-outputs = true;` to the same module.
3. Add `nix.settings.trusted-substituters` mirroring the substituter list.
4. Add `nix.registry.nixpkgs.flake = nixpkgs;` to the flake (or a host module) so `nix shell nixpkgs#X` uses the locked nixpkgs.
5. Sync `darwin/cachix.nix` to mirror `modules/base/cachix.nix` (fastly + full cachix list).
6. Update `bin/nixos-build` to use `nh os` for `switch` / `boot` / `test`; keep `nixos-rebuild` as a `--raw` escape hatch.
7. Document the new knobs in `docs/` and AGENTS.md (project rules around the new defaults).

A second cut, separately scoped, would tackle:
- Pinning nixpkgs to a commit.
- Removing t14's xdg-desktop-portal overlay (after upstream fix).
- Optional: Determinate Nix migration.

---

## 8. Reference Sources

External (exa search):
- Nixpkgs/nix #57477 — *nixos-rebuild switch too slow*
- Nixpkgs/nix #198668 — *nix.settings.max-jobs defaults to auto*
- Discourse #78481 — *Nixos-rebuild triggers enormous rebuilds*
- Discourse #65657 — *Why is nixos-rebuild switch upgrade-all rebuilding*
- Discourse #59569 — *Feature request: performance restricted rebuilds*
- Discourse #61099 — *Limit CPU usage when building*
- Discourse #74198 — *Nixos-rebuild takes forever*
- Discourse #31081 — *keep-outputs recommended by nix-direnv*
- Discourse #70810 — *Is inputs.*.inputs.nixpkgs.follows useful*
- Discourse #17413 — *Recommendations for use of flakes' input-follows*
- siraben.dev — *Dirty Nix flake quality-of-life hacks*
- UlyssesZh — *Reduce Nix rebuilds (store path replacement, etc.)*
- Farid Zakaria — *Automatic Nix flake follows*
- nix.dev — *Pinning Nixpkgs*
- nix.dev — *Cores vs Jobs*
- Determinate Systems — *Lazy Trees, Multithreaded Evaluation*
- cachix.org/docs — *What is a binary cache*
- nixos wiki — *Binary Cache, nixos-rebuild, nixos-rebuild-ng*

Internal (this repo):
- `flake.nix` lines 4-110 — inputs and follows
- `lib/mkHost.nix` — host wiring
- `modules/base/nix.nix` — current nix settings
- `modules/base/cachix.nix` — current substituter list
- `modules/base/nh.nix` — nh config
- `modules/base/home-manager.nix` — home-manager wiring
- `modules/profiles/base.nix` — what the server/desktop profiles import
- `overlays/linux.nix` — 4 package tweaks
- `hosts/rog/default.nix`, `hosts/t14/default.nix`, `hosts/thinkcentre/default.nix` — per-host overrides; t14 has the xdg-desktop-portal patch
- `darwin/cachix.nix` — Darwin side (incomplete)
- `bin/nixos-build` — current build wrapper (uses nixos-rebuild, not nh)
- `bin/format-nix` — formatter wrapper

Verified via nixos MCP option search:
- `nix.settings.substituters` — list of string
- `nix.settings.trusted-public-keys` — list of string
- `nix.settings.cores` — signed integer (0 = all cores)
- `nix.settings.trusted-substituters` — list of string

---

## 9. Risks / Open Questions for the User

- **Risk**: Setting `max-jobs = 1` will slow down "build many small packages in parallel" cases (e.g. a fresh bootstrap). Mitigation: allow per-host override.
- **Risk**: `keep-outputs = true` will grow /nix/store. Mitigation: rely on `nix.gc.automatic = false` and manual GC with `--delete-older-than 30d`.
- **Risk**: `nh` does not have full feature parity with `nixos-rebuild` (Discourse #23744). Mitigation: keep `nixos-rebuild` as a fallback; the wrapper supports both via a `--raw` flag.
- **Open question**: Does the user want to consider Determinate Nix? It's the single largest performance win but a significant OS-level change. Recommend deferring to a follow-up change.
- **Open question**: Does the user want to pin nixpkgs to a specific commit (Tier 2) or accept the moving branch? The 25.05 stable channel is a middle ground.

---

## 10. Delivery Strategy & Budget

| Field | Value |
|-------|-------|
| Estimated changed lines for Tier 1 only | ~30-50 net (3-4 modules, 1 bin script) |
| 400-line budget risk | **Low** |
| Chained PRs recommended | **No** (single PR is sufficient for Tier 1) |
| Tier 2 / 3 work, if approved | separate change, each scoped tightly |

End of exploration.

# Exploration: walker es lento (walker is slow)

## Current State

`walker` is the Omarchy desktop app launcher (`abenz1267/walker` v2.15.2), used on
the **t14** host (Hyprland/Omarchy). It is wired into the system via the
`omarchy-nix` flake input and bound to `SUPER+CTRL+SPACE` by default.

### Flow

1. **Keybind triggers** `omarchy-launch-walker`
   (`/home/glats/.local/share/omarchy/bin/omarchy-launch-walker`).
2. The script verifies the **elephant systemd user service** is running (it is
   a long-lived D-Bus/Unix-socket provider backend). If not, it starts it.
3. The script verifies the **walker gapplication service** is running
   (`walker --gapplication-service` under `uwsm-app`, env `GSK_RENDERER=cairo`).
4. The script `exec`s `walker --width 644 --maxheight 300 --minheight 300 ...`
   (a fresh GTK4 process per launch — no daemon reuse for the UI).
5. Walker connects to elephant over a local socket, queries the default
   providers (`desktopapplications`, `websearch`), and renders a `GtkGridView`.

### What "walker" actually is in this repo

| Layer | Path | Notes |
| --- | --- | --- |
| Flake input | `flake.nix:19` (`omarchy-nix`), transitive `flake.lock:1282` (`walker` v2.15.2) | pulled in via `omarchy-nix` flake |
| Walker deployment | `omarchy-nix/modules/nixos/system.nix:204` | installs `inputs.walker.packages.${system}.default` to `environment.systemPackages` |
| Elephant build | `omarchy-nix/modules/nixos/system.nix:12-50` | wraps `abenz1267/elephant` v2.17.2-patched + `elephant-providers` into one derivation |
| Elephant systemd service | `omarchy-nix/modules/nixos/system.nix:236-250` | `ExecStart` = `elephant-with-providers/bin/elephant`, started with `graphical-session.target` |
| Elephant env vars | `omarchy-nix/modules/nixos/system.nix:213-230` | sets `ELEPHANT_PROVIDER_DIR`, large `PATH` (8 entries, 2 nix profile dirs) |
| Walker config | `omarchy-nix/config/walker/config.toml` | `max_results = 256`, default providers = `desktopapplications`+`websearch` |
| Walker keybind | `omarchy-nix/modules/home-manager/hyprland/bindings.nix:33` | `SUPER CTRL, E, Emoji picker, exec, omarchy-launch-walker -m symbols` etc. |
| Walker CSS theme | `omarchy-nix/walker-theme/style.css`, `layout.xml` | GTK4 (GtkWindow, GtkGridView, GtkScrolledWindow) |
| Elephant provider config | `omarchy-nix/config/elephant/desktopapplications.toml` | `only_search_title = true`, `history = false`, `show_actions = false` |
| Local override (t14) | `hosts/t14/home/omarchy.nix` | does **not** override walker; uses upstream defaults |
| `omarchy-launch-walker` | `/home/glats/.local/share/omarchy/bin/omarchy-launch-walker` | systemd-aware launcher (replaces `pgrep -x elephant` with `systemctl --user is-active`); `GSK_RENDERER=cairo` |
| `omarchy-restart-walker` | `/home/glats/.local/share/omarchy/bin/omarchy-restart-walker` | restarts `elephant.service` + `app-walker@autostart.service` |

### Measured runtime state (live on t14)

- `elephant.service` active for ~1h 24min:
  - **MemoryCurrent = 456 MB** (peak 486 MB)
  - CPU = 5.95s total
  - systemd `app-walker@autostart.service` not present (walker is launched on demand)
- 24 user services running (Hyprland stack + thinkfan-ui, remmina, wayvnc, etc.)
- `~/.cache/elephant/` = **16 MB total**:
  - `files.db` 7.1 MB
  - `files.db-wal` 6.1 MB (WAL never checkpointed)
  - `clipboard.gob` 68 KB
  - `clipboardimages/` 2.0 MB
- SQLite query on `files.db`: **21,192 rows**
- 13,053 directories under `/home/glats` (massive inotify footprint)
- 84 .desktop files in `/run/current-system/sw/share/applications`, 18 in
  `/home/glats/.nix-profile/share/applications`, 7 in `~/.local/share/applications`
  → ~109 .desktop files; elephant parses 97 unique names (the rest are dupes
  by basename from the merged nix profile)

## Affected Areas

| File / Path | Why it's affected |
| --- | --- |
| `/home/glats/repos/omarchy-nix/modules/nixos/system.nix` (lines 12–50, 213–250) | defines elephant build, systemd service, env vars. **Out of tree** (lives in the `omarchy-nix` flake) — but the local `nixos-hosts` repo can override behavior. |
| `/home/glats/repos/omarchy-nix/config/walker/config.toml` | walker config (max_results, providers, prefixes). Out of tree. |
| `/home/glats/repos/omarchy-nix/config/elephant/desktopapplications.toml` | elephant provider config for .desktop files. Out of tree. |
| `/home/glats/repos/omarchy-nix/modules/home-manager/default.nix` (lines 118–143) | deploys the elephant + walker config files via home-manager. |
| `/home/glats/.local/share/omarchy/bin/omarchy-launch-walker` | launcher script (already fixed for elephant detection). |
| `/home/glats/.local/share/omarchy/bin/omarchy-restart-walker` | restart script. |
| `/home/glats/repos/omarchy-nix/modules/home-manager/hyprland/bindings.nix` | keybinds for walker invocations. |
| `hosts/t14/home/omarchy.nix` | local HM entry; **no walker override** today. This is the natural injection point. |
| `flake.nix:19-23` | omarchy-nix flake input. |
| `/home/glats/.cache/elephant/files.db[-wal\|-shm]` | runtime cache (~13 MB) — elephant deletes and rebuilds on every `elephant.service` start. |
| `/nix/store/lqqbhj6rg3j0d5r488bcpz58mablv31y-source/internal/providers/files/{setup,query,db}.go` | elephant v2.17.2 upstream source for the **files** provider (the main culprit). |

## Root Causes (ranked by impact)

### R1. `files` provider indexes the entire `$HOME` and never filters out build/VCS trees (HIGHEST IMPACT)

**Evidence:**
- `files.db` has **21,192 rows**.
- Top prefixes: `~/go/pkg/mod/` 19,491 rows (**92% of all indexed files**),
  `~/repos/omarchy-nix/` 641 rows, `~/go/pkg/mod/cache/download/` 661 rows.
- 13,053 directories in `/home/glats` are being watched by fsnotify.

**Why it matters:**
- Each file in the index triggers two stat syscalls at index time
  (`times.Stat` + `os.Stat`).
- Every fsnotify event in `$HOME` (`fd -type f` watching) triggers a 2-stat
  + SQLite write per changed path.
- The 6.1 MB WAL is the visible symptom: writes never checkpoint.
- Memory cost: elephant's Go heap holds 21K file entries in addition to the
  SQLite page cache (cache_size=10000 pages, ~40 MB heap), driving the
  456 MB RSS.

**Source:** `internal/providers/files/setup.go` — `search_dirs = $HOME`
default; `fd_flags = ['--ignore-vcs', '--type', 'file', '--type', 'directory']`
does **not** skip `target/`, `node_modules/`, `__pycache__/`, `.cargo/`,
`go/pkg/mod`, etc.

### R2. `files.db` is deleted and rebuilt on every elephant start (HIGH IMPACT)

**Evidence:**
- `internal/providers/files/db.go:19` runs `os.Remove(path)` at the top of
  `openDB()` — the cache is wiped on every restart.
- 13 MB of WAL + main db on disk is the working set; the user pays the index
  cost every time the session restarts (or after every `nixos-rebuild switch`,
  because `omarchy` HM activation restarts elephant — see
  `omarchy-nix/modules/home-manager/default.nix:197-208`).

**Cost:** ~10-30 seconds of `fd .` + 2 stat calls per file across
$HOME, even if the user hasn't actually changed anything.

### R3. fsnotify watches every directory under `$HOME` (HIGH IMPACT)

**Evidence:**
- `config.Watch = true` by default in the files provider.
- `shouldWatch()` only excludes `IgnoreWatching` regexes; default is empty.
- 13,053 dirs in `/home/glats` means 13K inotify watches held by elephant.
- Each `fd` scan result that ends in `/` calls `watcher.Add(path)` — every
  subdir of $HOME gets watched (line 202-205 of `setup.go`).
- Hitting `max_user_watches` (524288 on this host — fine) would degrade
  silently to reindexing. Even at 13K, the kernel overhead of stat-ing
  every changed file is non-trivial.

**Result:** heavy I/O tail from `go test`, `cargo build`, `git status`,
downloading files, etc. — every save/write in $HOME produces an elephant
write.

### R4. `max_results = 256` is very generous (MEDIUM IMPACT)

**Evidence:** `omarchy-nix/config/walker/config.toml:17`.

**Why it matters:**
- Walker renders 256 entries by default in the `GtkGridView`. On the t14
  display (1920x1080) the list can scroll significantly.
- Default providers (`desktopapplications`, `websearch`) only have ~57-83
  hits in practice, so this limit only matters when you use the `.` files
  prefix or the `/` providerlist — but with 21K indexed files, the
  `providerlist` rendering is the visible one.
- Fuzzy scoring on 21K files (`common.FuzzyScore` per row in
  `query.go:51`) costs ~milliseconds per keystroke on the worst case.

### R5. `runner` provider scans all of `$PATH` (LOW-MEDIUM IMPACT)

**Evidence:** `internal/providers/runner/setup.go:80-116`. On elephant
start: `runner executables=1592 time=183.633352ms`. With omarchy-nix's 8
PATH entries (mixing `/nix/store/*/bin`, `/etc/profiles/per-user/*/bin`,
etc.), this is 8 separate `fastwalk.Walk` passes.

**Why it matters:** 183 ms is not huge, but the runner provider is **not
enabled** in the default walker providers list — it loads but isn't
queried. The 183 ms is dead time. (Same for `bookmarks`, `bitwarden`,
`1password`, `nirisessions`, `niriactions`, `todo` — all loaded but
unused.) Loading ~14 providers is a one-time cost; only `files` keeps
working in the background.

### R6. GSK_RENDERER=cairo forces software rendering (MEDIUM IMPACT, environment-specific)

**Evidence:** `omarchy-launch-walker:18` sets `GSK_RENDERER=cairo`. This
disables the GL/nvidia/llvmpipe renderer path. On the t14 (AMD iGPU),
this is the conservative choice for Wayland compositors that don't expose
the proper EGL/GBM stack, but it means the **GTK4 UI rendering happens
on the CPU** — every frame, every blur, every list scroll uses CPU.
Walker is small (644×300) so this is small absolute work, but
perceptible under load.

### R7. WAL never checkpointed (LOW IMPACT, drives symptom of R1+R3)

**Evidence:** `files.db-wal` is 6.1 MB. The elephant `files` provider
never calls `PRAGMA wal_checkpoint(TRUNCATE)`. SQLite keeps the WAL until
the last connection closes. With elephant's connection held open
indefinitely, the WAL only grows.

### R8. Walker is launched as a fresh process every time (LOW IMPACT)

**Evidence:** `omarchy-launch-walker:21` does `exec walker ...`. There is
no `--reuse` mode in walker. Each keypress = new process = new GTK init,
new DBus roundtrips, new CSS parsing, new font load. The
`walker --gapplication-service` daemon is started for D-Bus
service activation, but the actual UI is a separate process.

### R9. Two stat calls per file at index time (LOW IMPACT, source-side)

**Evidence:** `internal/providers/files/setup.go:165-184` calls
`times.Stat`; later at line 207 the same loop calls `times.Stat` again;
the `handleRegular` path (`setup.go:302-311`) calls both `times.Stat`
and `os.Stat`. Each stat is a syscall + a Go-Map lookup.

## Approaches

### Option A — Trim the `files` provider's search scope and watch set (LOW EFFORT, HIGH IMPACT)

Add a per-host elephant config that narrows `files.search_dirs` to a
curated set of useful directories and excludes known-noisy trees.

```toml
# ~/.config/elephant/files.toml
search_dirs = ["~/Documents", "~/Downloads", "~/Desktop", "~/Pictures", "~/projects"]
ignored_dirs = [
  "/\\.git/",
  "/node_modules/",
  "/target/",
  "/\\.cargo/",
  "/go/pkg/mod/",
  "/__pycache__/",
  "/\\.cache/",
  "/\\.nix-profile/",
]
ignore_watching = ["/go/", "/repos/", "/\\.local/share/omarchy/"]
watch = true
fd_flags = [
  "--ignore-vcs", "--hidden",
  "--type", "file", "--type", "directory",
  "--exclude", ".git", "--exclude", "node_modules",
  "--exclude", "target", "--exclude", "__pycache__",
]
```

- **Pros:** Directly addresses R1+R3 (92% of indexed files disappear,
  watch count drops by 1–2 orders of magnitude). No flake change required —
  just `xdg.configFile."elephant/files.toml".text = ...` in
  `hosts/t14/home/omarchy.nix`. Elephant re-indexes on next `omarchy-restart-walker`.
- **Cons:** User has to know the noisiest trees. May need to revisit
  when adding a new project dir. omarchy-nix upstream may eventually
  ship sensible defaults.
- **Effort:** Low (~10 lines of Nix + a comment).

### Option B — Override `max_results` + narrow default providers (LOW EFFORT, MEDIUM IMPACT)

Lower `max_results` to a saner number (e.g. 64) and consider trimming the
default provider list. Walker is an app launcher; you don't need 256
results on the first keystroke.

- **Pros:** Faster fuzzy scoring (R4), less UI rendering work (R6). One
  line change in walker config.
- **Cons:** 64 might feel limiting to a power user. Doesn't fix the
  underlying indexing cost.
- **Effort:** Trivial.

### Option C — Disable the `runner` provider (LOW EFFORT, MEDIUM IMPACT)

The `runner` provider is loaded but never queried (not in default
providers). Disabling it via elephant's provider selection saves the
183 ms `fastwalk` over $PATH on every elephant restart.

Looking at upstream elephant config: there is no `disable_providers`
flag in the global config (only per-provider `enable = false` via
config). However, elephant loads all `.so` files in
`ELEPHANT_PROVIDER_DIR`. To skip the runner, the easiest local change
is to remove `runner.so` from the elephant-providers derivation — but
that requires a **upstream omarchy-nix patch** (out of tree here).

- **Pros:** 183 ms off every elephant start. No user-facing change.
- **Cons:** Requires editing the omarchy-nix flake, not just nixos-hosts.
  We have push access (`github.com/glats/omarchy-nix`), so we can land
  a PR — but it's a cross-repo change.
- **Effort:** Medium (PR + bump omarchy-nix in nixos-hosts).

### Option D — Drop GSK_RENDERER=cairo and let GTK pick (LOW EFFORT, MEDIUM IMPACT)

Hyprland on t14 (AMD) supports the proper Wayland rendering pipeline.
Removing the env var lets GTK pick `GSK_RENDERER=ngl` (the OpenGL
backend) automatically.

- **Pros:** UI is GPU-accelerated → smoother scroll, less CPU during
  animation. Walker is small but the blur/alpha effects add up.
- **Cons:** If the Wayland session doesn't expose a working GL context,
  walker will fall back to broadway or fail to start. Hyprland on AMD
  has been stable for this since 0.45+, but it's a regression risk.
- **Effort:** Trivial (1-line change in `omarchy-launch-walker`),
  but it's a **upstream omarchy-nix change** again.

### Option E — Patch elephant to (a) keep `files.db` across restarts and (b) checkpoint WAL (HIGH EFFORT, MEDIUM IMPACT)

Direct fix to elephant's `files/db.go`:
- Remove the `os.Remove(path)` in `openDB()` — let the index persist
  across restarts.
- Add a periodic `PRAGMA wal_checkpoint(TRUNCATE)` (e.g. every 5 min).

- **Pros:** R2 disappears. Restart cost drops from 10-30s to <1s.
- **Cons:** Elephant is a Go plugin loaded from `elephant-providers`;
  patching it means maintaining a fork. Could be done via a local
  `elephant-with-providers` override in omarchy-nix.
- **Effort:** High (fork + maintenance).

### Option F — Switch the default provider from `desktopapplications` to `runner` (LOW EFFORT, CONTEXTUAL)

For users who use walker as a "run anything" prompt (and already have
their GUI apps in the dock/waybar), `runner` (1,592 executables from
$PATH) is faster than `desktopapplications` for the "type 3 letters
and hit enter" workflow.

- **Pros:** Faster first-result time on common queries (terminal apps).
- **Cons:** Loses icons and proper app names. Two default providers
  means walker queries both — defeats the purpose.
- **Effort:** Trivial (config change).

### Option G — Bump elephant to 2.20.3 (upstream) (MEDIUM EFFORT, UNKNOWN IMPACT)

The local omarchy-nix pins elephant to 2.17.2-patched. nixpkgs has
2.20.3 in unstable (visible in the .drv path
`09sbfqrda2z160cx0mlyi5xjgj70zjah-elephant-2.20.3-go-modules.drv`).
Bumping could bring perf fixes — but the version is set in
omarchy-nix, not nixos-hosts, so this is again a **cross-repo
change**.

- **Effort:** Medium (PR + test).

## Recommendation

**Combine A + B as the local fix (in `nixos-hosts` repo only):**

1. **A** (files.toml override in `hosts/t14/home/omarchy.nix`) is the
   single biggest win — drops the 19K go/pkg/mod entries and ~12K of
   the 13K fsnotify watches. ~80% of the visible "walker is slow" cost
   goes away.
2. **B** (`max_results = 64`) is a 1-line change that makes the
   rendered list smaller and reduces fuzzy-scoring work per keystroke.

This is fully **in the nixos-hosts repo** (no omarchy-nix change), so
it can be reviewed, merged, and reverted in one place. The other
options (C, D, E, G) require editing the omarchy-nix flake — possible
because we own that repo, but a separate decision.

**Estimated impact (rough):**
- elephant RSS: 456 MB → **~80–120 MB** (smaller db, smaller watch set)
- elephant index time on restart: ~10–30s → **<500 ms**
- fsnotify event storm during builds: ~linear in 21K → **constant per
  changed file in watched dirs only**
- walker query latency: ~1ms → ~1ms (no change for the fast paths)
- walker first-result latency: perceptible (R6 software renderer) → unchanged

**Trade-off:** User has to maintain a curated `ignored_dirs` list when
they add new project roots. The list is documented in
`hosts/t14/home/omarchy.nix` with comments so the cost is low.

## Risks

- **R-A:** Some users actually *want* to launch files in `~/go/pkg/mod/`
  or other excluded trees. Mitigation: leave `ignored_dirs` narrow
  enough to only block clearly-noisy paths (`go/pkg/mod`, `node_modules`,
  `target`, `__pycache__`, `.git`).
- **R-B:** omarchy-nix might add an `elephant/files.toml` of its own in
  a future release, causing a conflict. Mitigation: check upstream
  before bumping the omarchy-nix input. The change is HM-scoped to
  `hosts/t14/home/omarchy.nix`, so other hosts are unaffected.
- **R-C:** If `omarchy-restart-walker` is required to pick up the new
  config (it is), users on a fresh `home-manager switch` won't see the
  improvement until they restart elephant. Mitigation: document the
  one-liner in a comment in the file.
- **R-D:** Reducing `max_results` to 64 may feel limiting for users who
  intentionally scroll through long lists. Mitigation: keep the value
  configurable in a comment so the user can flip it.
- **R-E:** Patching the `omarchy-launch-walker` script (option D) is
  out of tree; if the upstream script diverges, local patches may be
  overwritten on omarchy-nix bump. Mitigation: don't take D in this
  change — leave it for a follow-up PR against omarchy-nix.

## Next Steps

1. Land A + B in nixos-hosts as a single change.
2. Re-measure elephant RSS + files.db row count after the change is
   applied.
3. Open a follow-up issue in `glats/omarchy-nix` for option C
   (disable `runner` provider) and option D (drop `GSK_RENDERER=cairo`).
4. Consider option E (patch elephant to preserve `files.db` across
   restarts) as a longer-term win — but it requires forking
   `elephant-providers` or upstreaming a `cache_persist` config flag.

## Ready for Proposal

**Yes** — for option A + B (in-repo, low risk, high impact). The
exploration has identified the exact files, the exact numbers, and the
exact change required. The orchestrator can move to the proposal phase
to write the formal change proposal.

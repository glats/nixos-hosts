## Exploration: se perdio mi arreglo de flameshot con algunos cambios. de git

### Current State

**Flameshot is still partially configured**, but only for MATE — the rest of the ecosystem around it was deleted in a single "workg" commit.

| Where | Status | Notes |
|---|---|---|
| `modules/base/profiles/base.nix` line 110 | Present | `flameshot` package installed system-wide for all hosts |
| `home-linux/mate.nix` lines 278-293 | Present | MATE autostart `.desktop` for `org.flameshot.Flameshot` |
| `home-linux/mate.nix` lines 221-226 | Present | `org/mate/screenshot` dconf settings (border-effect, delay, include-border, include-pointer) |
| `darwin/homebrew.nix` line 46 | Present | macOS homebrew install for `mact2` |
| `bin/export-mate-config` lines 146-161 | Present | Helper script generates MATE autostart from current config |
| `modules/home/cinnamon.nix` | **DELETED** (was 198 lines) | DELETED in `ffb327c` |
| `modules/home/xfce.nix` | **DELETED** (was 55 lines) | DELETED in `ffb327c` |
| `modules/desktop/xfce-defaults.nix` | **DELETED** (was 30 lines) | DELETED in `ffb327c` |
| `modules/features/services/xrdp.nix` | **Simplified** | Reduced from 80 lines (multi-DE picker) to ~20 lines (MATE-only loop) |
| `bin/xrdp-back-to-picker` | **DELETED** (was 103 lines) | DELETED in `ffb327c` |
| XRDP session picker (MATE/XFCE/Cinnamon) | **REMOVED** | Now hardcoded MATE only on rog/thinkcentre |

**Net deletion in `ffb327c`**: 14 files changed, 38 insertions, **494 deletions**.

### Affected Areas

- `modules/home/cinnamon.nix` — DELETED in `ffb327c workg` (May 18, 2026). Previously contained Cinnamon dconf, gnome-terminal palette, and **flameshot autostart** for Cinnamon sessions.
- `modules/home/xfce.nix` — DELETED in `ffb327c workg`. Previously contained XFCE xfconf settings, screensaver/power disables, and **flameshot autostart** for XFCE sessions.
- `modules/desktop/xfce-defaults.nix` — DELETED in `ffb327c workg`. System-wide XFCE defaults (`xfce4-desktop.xml` background config) installed via `environment.etc`. Used to provide a solid-black backdrop fallback for any new monitor in xrdp sessions.
- `modules/features/services/xrdp.nix` — Simplified in `ffb327c workg`. Lost the rofi-based DE picker (MATE/XFCE/Cinnamon), per-session log routing, DE-specific env exports, and the `cinnamon --replace` cleanup. Now runs MATE directly with a `while true` loop.
- `bin/xrdp-back-to-picker` — DELETED in `ffb327c workg`. Companion script invoked from the per-DE `xdg.dataFile."applications/xrdp-back-to-picker.desktop"` entry. Removal also removed the "Back to Session Picker" launcher from MATE and Cinnamon menus.
- `modules/home/mate.nix` — Lost the `xdg.dataFile."applications/xrdp-back-to-picker.desktop"` block (12 lines) in `ffb327c workg`. The MATE flameshot autostart itself is intact.
- `modules/desktop/xrdp.nix` — Deleted in `3fc8e52 refactor: restructure to base+features architecture` (Apr 25). Moved to `modules/features/desktop/xrdp.nix`, then to `modules/features/services/xrdp.nix`, then to `hosts/{rog,thinkcentre}/services/xrdp.nix`, then **never added back to either host's services** (rog/thinkcentre both have xrdp NixOS services enabled but no per-host `xrdp.nix`).

### Timeline (git history of flameshot-related changes)

| Commit | Date | What happened |
|---|---|---|
| `421d20a` | Apr 23 15:34 | `feat(home): add xfce and cinnamon modules, xrdp session logging` — **created** `modules/home/xfce.nix` and `modules/home/cinnamon.nix` **with** flameshot autostart for both |
| `7c62a02` | Apr 23 18:49 | `feat(home): rewrite xfce and cinnamon modules with proper DE config` — **removed** CopyQ, Flameshot, Hexchat autostart from both files ("use native DE tools"); replaced raw xdg.configFile blocks with proper xfconf.settings / dconf.settings |
| `0d0b855` | Apr 23 18:52 | `fix(home): remove rofi shortcuts and unused params from xfce/cinnamon` — "Flameshot already removed from both in previous commit" |
| `76e1f1b` | Apr 23 18:59 | `feat(home/mate): declare power-manager and screenshot settings` — added MATE-specific lid/suspend button actions and MATE screenshot defaults |
| `3fc8e52` | Apr 25 12:59 | `refactor: restructure to base+features architecture` — moved `modules/core/*` → `modules/base/*`, moved `modules/desktop/*` → `modules/features/desktop/*` |
| `2f16d92` | May 3 00:59 | `refactor(nixos): restructure to Services Directory pattern, deduplicate configs` — split services per-host; "Temporarily disable xfconf.settings (causes failures in headless sessions)" |
| **`ffb327c`** | **May 18 15:29** | **`workg`** — **DELETED** `modules/home/cinnamon.nix` (198 lines), `modules/home/xfce.nix` (55 lines), `modules/desktop/xfce-defaults.nix` (30 lines), `bin/xrdp-back-to-picker` (103 lines); simplified xrdp.nix to MATE-only; removed picker desktop entries. **This is where the flameshot-with-other-DEs support was lost.** |

The first three commits (Apr 23) are an honest "remove flameshot from xfce/cinnamon because native DE tools exist" cleanup. The real loss is `ffb327c` (May 18), a single commit with a Spanish typo title ("workg" = "working" in the user's voice) that deleted everything XFCE/Cinnamon/xrdp-picker-related in one sweep.

### Hosts affected

- **rog** (desktop, MATE via xrdp) — Uses MATE only since `ffb327c`. MATE flameshot still works. Lost access to XFCE/Cinnamon sessions via xrdp picker.
- **thinkcentre** (headless, MATE via xrdp) — Same as rog. MATE flameshot still works. Lost access to XFCE/Cinnamon sessions.
- **t14** (laptop, Hyprland/Omarchy) — Not affected. Uses Hyprland's native screenshot tooling (grim+slurp via Hyprland keybindings, owned by `omarchy-nix`). Flameshot was never configured for t14.
- **mact2** (macOS) — Not affected. Uses `homebrew "flameshot"` (line 46 of `darwin/homebrew.nix`).

### What was the "fix" / "arreglo"?

Most likely one of these interpretations:

1. **Most likely**: The flameshot autostart `.desktop` entries for Cinnamon and XFCE, which were added in `421d20a` then removed in `7c62a02` and finally purged entirely when the parent files were deleted in `ffb327c`. If the user re-added these blocks manually between `7c62a02` and `ffb327c`, that custom re-addition was lost.

2. **Less likely but possible**: The `xdg.dataFile."applications/xrdp-back-to-picker.desktop"` entry in `modules/home/mate.nix` (line ~245 in the pre-`ffb327c` version). Removed in the same sweep.

3. **Possibly**: The "Back to Session Picker" workflow — if the user was using that to switch between MATE/XFCE/Cinnamon, the entire picker (rofi menu, the launcher entries, the script) is gone.

To determine which one the user actually means, the most actionable next step is to ask: *"¿Cuál era tu arreglo? ¿El autostart de flameshot en Cinnamon/XFCE, o el picker de sesión de xrdp, o algo más?"* The MATE autostart is still there.

### Approaches

1. **Restore the deleted files as-is from `ffb327c~1` (snapshot at parent commit)**
   - Pros: One git checkout; recovers everything verbatim including the user's potential custom edits between `7c62a02` and `ffb327c`. Includes xfce-defaults.nix and the xrdp picker script.
   - Cons: Files were deleted for a reason (`ffb327c` message suggests xrdp-picker was being simplified). Restoring blindly re-introduces the multi-DE complexity and the xfconf headless-session issue noted in `2f16d92`. May re-trigger the "xfconf.settings causes failures in headless sessions" warning.
   - Effort: Low (mechanical)

2. **Add flameshot autostart directly to a base module (`home-linux/base.nix`) so it works in any DE**
   - Pros: Single source of truth; survives DE changes; doesn't need xfce.nix or cinnamon.nix to exist; aligns with the user's MATE-only direction post-`ffb327c`. Removes the `OnlyShowIn=MATE;` restriction so the autostart fires under any DE that loads the home config.
   - Cons: May not match the user's intent if they specifically wanted flameshot only in Cinnamon or XFCE.
   - Effort: Low (one block in `base.nix`)

3. **Recreate the `cinnamon.nix` + `xfce.nix` files, keeping only the flameshot autostart (no full DE config)**
   - Pros: Preserves DE-specific OnlyShowIn scoping. If the user later wants to use Cinnamon or XFCE via xrdp again, the autostart already wires up. Cheaper than a full restore.
   - Cons: Two new files for what's effectively a 14-line autostart block each. MATE has no use for these.
   - Effort: Low–Medium

4. **Restore the full xrdp session picker (MATE/XFCE/Cinnamon) AND the flameshot autostart in those DEs**
   - Pros: Recovers the original multi-DE setup the user had working. Most complete "restore my workflow" answer.
   - Cons: Largest blast radius. Reverts `ffb327c`'s simplification. Multi-DE xrdp had known issues (per `2f16d92` and the xfconf headless warning, plus the `cinnamon --replace` watchdog kill in `b7ab342`). xrdp.nix would need to live somewhere (e.g., `hosts/rog/services/xrdp.nix` or `hosts/thinkcentre/services/xrdp.nix`).
   - Effort: High (restore 4 files + rewire xrdp)

### Recommendation

**Approach 2** (add flameshot autostart to `home-linux/base.nix`) if the user wants flameshot to "just work" regardless of DE. **Approach 1** (verbatim restore) if the user explicitly wants the multi-DE xrdp picker back with flameshot in Cinnamon/XFCE.

The MATE flameshot is intact — if the user is on MATE (which they are on rog/thinkcentre post-`ffb327c`), screenshots already work. The "lost" config only matters if:

- They want flameshot to autostart under Cinnamon or XFCE specifically, OR
- They want the XRDP session picker back so they can pick a non-MATE DE.

Before applying anything, ask the user which of these matches their "arreglo". A single sentence of clarification will determine whether we go with Approach 1, 2, 3, or 4.

### Risks

- **Stash conflict**: `stash@{2}` is a WIP on `421d20a` (when xfce/cinnamon were first added) and contains a partial `cinnamon.nix` rewrite. Restoring from `ffb327c~1` may conflict with this stash if the user pops it later. Recommend `git stash drop stash@{2}` after confirming the restore is correct.
- **xrdp regression risk**: The `ffb327c` simplification fixed a known issue where `xfconf.settings` failed in headless sessions (`2f16d92` note) and where Cinnamon needed a `--replace` watchdog kill (`b7ab342`). Restoring the full xrdp picker would re-introduce both.
- **Flameshot DBus quirk in MATE**: The current `home-linux/mate.nix` autostart uses `OnlyShowIn=MATE;` and `X-MATE-Autostart-enabled=true`. Works correctly. If moving to a base module, dropping the `OnlyShowIn` filter means the same `.desktop` would try to autostart under any DE that reads the XDG autostart dirs (which is fine in practice — flameshot is a single-instance app guarded by DBus activation).
- **Hidden autostart from MATE screensaver/power-manager disable pairs**: The deleted `cinnamon.nix` and `xfce.nix` also contained `cinnamon-screensaver.desktop`, `cinnamon-power-manager.desktop`, `xfce4-screensaver.desktop`, `xfce4-power-manager.desktop` (all with `Hidden=true` for xrdp compatibility). If the user ever runs Cinnamon or XFCE via xrdp, those will be missing.
- **`xrdp` is still enabled at the system level** in `rog/thinkcentre` (via `my.desktop.suite = "mate"` → `modules/base/profiles/desktop.nix`), but there is no per-host `hosts/{rog,thinkcentre}/services/xrdp.nix` file. The current xrdp behavior comes from `modules/features/services/xrdp.nix` which is imported transitively, but post-`ffb327c` it only sets up a MATE session loop. Adding back a picker would require either restoring that file's old content or creating per-host xrdp.nix files.

### Ready for Proposal

**No — clarification needed first.**

The user must specify which "arreglo" was lost before we can propose a fix. The MATE flameshot is intact. The likely candidates are:

1. The flameshot autostart for Cinnamon or XFCE (Approach 1 or 3)
2. The XRDP session picker that allowed choosing MATE/XFCE/Cinnamon (Approach 4)
3. A global flameshot autostart that works in any DE (Approach 2)

Once the user picks, this can move to `sdd-propose` with a clear scope.

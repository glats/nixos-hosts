# Exploration: se perdio theme glats pallete de btop para todos los hosts en nixos

## Current State

The btop theming pipeline is **architecturally correct** at the source level — every NixOS host has the glats palette flowing into `~/.config/btop/themes/nix-colors.theme` and `btop.conf`/`programs.btop.settings` references it. The user's past-tense complaint ("se perdió") suggests a regression in the **rendered output** rather than the source.

### Theme pipeline per host (today)

| Host   | `colorScheme.palette` source                          | Theme file written                                                       | Conf writes                              | `color_theme` value           |
| ------ | ------------------------------------------------------ | ------------------------------------------------------------------------ | ---------------------------------------- | ----------------------------- |
| rog    | `home-linux/theme.nix` → `shared/palette.nix`         | `home-linux/btop-theme.nix` → `~/.config/btop/themes/nix-colors.theme`    | `home-linux/btop-file.nix` (raw `home.file`) | `"nix-colors"`               |
| thinkcentre | same as rog                                          | same as rog                                                              | same as rog                              | `"nix-colors"`               |
| t14    | `omarchy-nix/modules/custom-base16-schemes.nix` (glats) | **two writers** to `~/.config/btop/themes/`:<br>1. `home-linux/btop-theme.nix` → `nix-colors.theme`<br>2. `omarchy-nix/modules/home-manager/btop.nix` → `glats.theme` | `home-linux/btop-settings.nix` (HM `programs.btop.settings` with `lib.mkForce` on each key) | `lib.mkForce "nix-colors"`   |

**Key facts** (verified against files and upstream sources):

- All three hosts use the same canonical glats palette. The `shared/palette.nix` (rog/thinkcentre) and the `glats` entry in `omarchy-nix/modules/custom-base16-schemes.nix` (t14) contain **identical hex values** byte-for-byte (`base00=000000` … `base0F=ff6600`, plus the legacy bright aliases).
- The btop binary is `btop 1.4.6` from `nixos-unstable` (1.4.7 was released 2026-05-21 upstream; not yet adopted in this repo's lock). The btop 1.4.7 changelog shows **no theme format changes** (`theme[key]="#hex"` is still the only supported syntax). Format compatibility is not the cause.
- `home-manager`'s `programs.btop` module (HM `master` `modules/programs/btop.nix`) exists and supports `programs.btop.settings` and `programs.btop.themes`. The repo does **not** set `programs.btop.themes` anywhere — all theme writing is via `home.file."~/.config/btop/themes/..."`. No `home.file` ↔ `xdg.configFile` collision for the btop paths.
- btop reads `~/.config/btop/themes/<color_theme>.theme` (or `~/.config/btop/themes/<color_theme>`). With `color_theme = "nix-colors"`, the file the runtime actually loads is `nix-colors.theme` — the `glats.theme` written by omarchy-nix on t14 is **dead code**.
- `save_config_on_exit = false` on all three Linux hosts (rog, thinkcentre via `btop-file.nix`; t14 via `btop-settings.nix`). The macOS path (`home-darwin/btop.nix`) sets it to `true`, but the user explicitly scoped the report to NixOS hosts, so macOS is not implicated.

### Historical context (from Engram)

Prior sessions fixed three issues that **are not currently broken** (re-verified above):
1. `#1258` — omarchy-nix's `modules/home-manager/btop.nix` was emitting hex without `#` prefix. Currently emits `theme[main_fg]="#${palette.base05}"` — **fixed**.
2. `#1263` — palette divergence between `shared/palette.nix` (neon) and `omarchy-nix` (muted retro). Currently **identical**.
3. `#1269` — btop attribute mapping divergence (omarchy-nix monochrome vs. nixos-hosts semantic rainbow). This is the only **known-unresolved** drift, but it only affects visual styling of borders and gradients, not whether the theme is *applied at all*.

### Most recent commits touching btop

- `7982318` (2026-06-23) — **style-only** refactor of `home-linux/btop-theme.nix`, `home-linux/btop-settings.nix`, `hosts/t14/home/omarchy.nix` argument list formatting (`{ config, ... }` → `{ config, ..., }`). No semantic change.
- `833c613` (2026-06-26) — nixpkgs bump to 2026-06-26 (potential btop version bump; no theme format change in 1.4.7 changelog).
- `3169c77` (2026-06-26) — xdg-desktop-portal patch regen. No btop impact.

No recent commit altered the btop theme content.

## Affected Areas

- `home-linux/btop-theme.nix` — canonical theme fragment. Writes `nix-colors.theme` (hard-coded file name) from `config.colorScheme.palette`. **Single source of truth for the btop theme FILE content** across all three Linux hosts.
- `home-linux/btop-file.nix` — file-based `btop.conf` for rog/thinkcentre. Sets `color_theme = "nix-colors"`, `save_config_on_exit = false`. Does **not** set `programs.btop.*` (uses raw `home.file`).
- `home-linux/btop-settings.nix` — HM `programs.btop.settings` for t14 with `lib.mkForce` on every key. Drops omarchy-nix's defaults. **Visual drift from rog/thinkcentre** is a known issue (omarchy keys not overridden by t14's `lib.mkForce` win, e.g. `cpu_graph_upper = "total"` vs. rog's `"Auto"`; `shown_boxes` differs by `gpu`).
- `home-linux/shared-modules.nix` — canonical module list for rog/thinkcentre. Includes `btop-theme.nix` (line 18) and is consumed by both `hosts/rog/home/modules.nix` and `hosts/thinkcentre/home/modules.nix`.
- `hosts/rog/home/modules.nix` — imports `btop-file.nix` (line 13) on top of `shared-modules.nix`. ✓
- `hosts/thinkcentre/home/modules.nix` — imports `btop-file.nix` (line 11) on top of `shared-modules.nix`. ✓
- `hosts/t14/home/omarchy.nix` — imports `btop-theme.nix` (line 77) and `btop-settings.nix` (line 78) directly (not via `shared-modules.nix`). Confirmed in the file. ✓
- `shared/palette.nix` — defines the glats palette. Used by rog/thinkcentre via `home-linux/theme.nix`.
- `inputs.omarchy-nix/modules/custom-base16-schemes.nix` (upstream) — defines the glats entry used by t14 via `omarchy.theme = "glats"`. **Currently identical to `shared/palette.nix`** (verified via `webfetch` on 2026-06-26).
- `inputs.omarchy-nix/modules/home-manager/btop.nix` (upstream) — writes `~/.config/btop/themes/${cfg.theme}.theme` (= `glats.theme` on t14) and sets `programs.btop.settings.color_theme = cfg.theme` (= `"glats"`). On t14, this is overridden by our `lib.mkForce "nix-colors"`, so the `glats.theme` file is never read by btop but is still written to disk.
- `inputs.omarchy-nix/modules/home-manager/theme-generator.nix` (upstream) — generates `~/.config/omarchy/themes/<theme>/btop.theme` (different directory). This is for omarchy's own theme picker and is **not** the active btop theme.
- `modules/hardware/nvidia.nix` (rog) — wraps btop with `btopWithCuda = pkgs.btop.override { cudaSupport = true; }` and a `security.wrappers.btop` setcap entry. Theme file path is identical; no impact on the theme file.
- `modules/base/profiles/base.nix` line 43 — `btop` in `environment.systemPackages` for all hosts.

## Approaches

### 1. **Consolidate to a single named theme file `glats.theme`** *(preferred)*

- Rename the theme file from `~/.config/btop/themes/nix-colors.theme` to `~/.config/btop/themes/glats.theme` in `home-linux/btop-theme.nix`.
- Update `color_theme` references: `"nix-colors"` → `"glats"` in `home-linux/btop-file.nix` and `home-linux/btop-settings.nix`.
- On t14, omarchy-nix already writes `glats.theme` from the (identical) glats palette. With our own `home-linux/btop-theme.nix` also writing it, **the two writers now produce the same file** (same path, same content) — no conflict, no dead code. The `lib.mkForce "nix-colors"` on t14 becomes `lib.mkForce "glats"` (or removed entirely, since omarchy's default is already `"glats"`).
- **Pros**: Single conceptual identity (`glats` everywhere). Eliminates the dual-writer dead-code situation on t14. File name now matches the palette name and the omarchy convention. No upstream coordination needed.
- **Cons**: Touches three files; one-line changes but a re-activation is required on each host.
- **Effort**: Low.

### 2. **Diagnose without source changes — add a runtime smoke test**

- Add a flake check or HM activation assertion that verifies `~/.config/btop/themes/nix-colors.theme` exists and contains the expected hex for `base05` after `home-manager switch`.
- Optionally script `btop --help` parsing or `btop --themes-dir` listing to confirm the theme is discoverable.
- **Pros**: No semantic change to the existing pipeline; surfaces the actual failure mode (file missing? format wrong? btop version mismatch?).
- **Cons**: Does not fix the underlying issue; only diagnoses. The user is reporting a regression — diagnosis is the first step regardless of which fix is chosen.
- **Effort**: Low (script) to Medium (flake-level check).

### 3. **Switch t14 to use the glats palette via shared source** *(largest change)*

- Replace the local `home-linux/btop-theme.nix` import on t14 with a theme file sourced from `inputs.omarchy-nix` or have t14 read `shared/palette.nix` directly.
- Stop the `lib.mkForce` chain on t14 entirely; let omarchy-nix's btop.nix own the config.
- **Pros**: Maximum reuse of upstream. Eliminates the dual source of truth.
- **Cons**: Reintroduces the visual mapping drift from #1269 (omarchy-nix btop.nix is monochrome, our shared fragment is semantic rainbow). The user's prior session explicitly chose the `lib.mkForce` chain to keep all three hosts visually identical. **Reverting this is a known regression**.
- **Effort**: High. Requires upstream PR or local fork changes.

## Recommendation

**Approach 1 (rename to `glats.theme`)**. Reasons:
- Smallest change that fixes the most likely real-world problem: the user perceives the theme as "lost", and the `nix-colors` filename is semantically opaque — it does not tell the user that this is the *glats* theme. A user looking at `~/.config/btop/themes/` sees a file named `nix-colors.theme` and may think the "real" glats theme is missing.
- It eliminates the dual-writer dead-code situation on t14 without changing any visual semantics.
- It does not reintroduce the #1269 mapping drift.
- It works even if omarchy-nix evolves: as long as omarchy's btop.nix keeps writing `glats.theme` from a palette, and our shared fragment also writes `glats.theme` from the same palette, they produce identical files.

**Pre-flight before applying**: run `nix flake check --no-build` and `btop --version` on each host to confirm the current state. If the theme file is actually present and correct on disk but btop is not loading it, the issue is at the btop layer (config, env var, or binary) and Approach 2 is needed as a diagnostic step.

## Risks

- **btop 1.4.7 theme load order**: When the nixpkgs bump lands 1.4.7, the new themes ship in `/usr/share/btop/themes/`. Btop's lookup order is system dir first, then user dir. A user `glats.theme` will override the system one if both exist. **Low risk** — there is no upstream `glats.theme`.
- **Hidden `home.file` collision** on t14: After Approach 1, `home-linux/btop-theme.nix` and `omarchy-nix btop.nix` will both write `~/.config/btop/themes/glats.theme`. HM's `home.file` is an `attrsOf`, so the two writes **collide** — the second one wins. Because both sources produce identical content today, this is silent. If `shared/palette.nix` and omarchy's `glats` scheme drift in the future, the btop theme will silently use the loser. **Mitigation**: in Approach 1, also remove the `inputs.omarchy-nix.homeManagerModules.default` import of btop on t14, OR keep our `home-linux/btop-theme.nix` and add `lib.mkForce` on the omarchy `home.file` entry. **Medium risk** — must be addressed in the same change.
- **macOS** is not in scope per the user's report, but `home-darwin/btop.nix` is independent and uses the same `nix-colors.theme` filename + `color_theme = "nix-colors"`. Approach 1 should rename it too for consistency (or stay untouched if we keep the existing `nix-colors` convention on darwin). **Low risk** — out of scope but worth a follow-up.
- **`save_config_on_exit = true` on darwin** can overwrite the managed `nix-colors.theme` if the user picks the theme interactively. Not a Linux issue, but the parallel change on darwin would inherit the same risk on a renamed file. **Low risk** — out of scope.
- **Visual drift between rog/thinkcentre and t14** (the #1269 issue) is **not fixed** by Approach 1. The user accepted this drift in #1269. If they want it closed, Approach 3 is required, which is a larger lift.

## Ready for Proposal

Yes. The recommendation (Approach 1) is concrete and small. Pre-flight: run `nix flake check --no-build` once before drafting the proposal to confirm the existing pipeline evaluates.

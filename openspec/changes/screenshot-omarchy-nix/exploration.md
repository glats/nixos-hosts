# Exploration: screenshot-omarchy-nix

## Problem Statement

The user wants screenshot functionality on the t14 Hyprland host (running
`omarchy-nix`) that matches what the `basecamp/omarchy` Arch Linux flavor
provides — region / windows / fullscreen capture, post-capture editing in
satty, OCR, color picker, and the matching Hyprland keybindings + omarchy
menu integration.

The upstream `glats/omarchy-nix` module (pinned via `inputs.omarchy-nix`
in `flake.nix`) is a fork of `basecamp/omarchy` and ships the
`omarchy-capture-screenshot`, `omarchy-capture-text-extraction`,
`omarchy-capture-screenrecording`, and `omarchy-screenrecord` scripts in
its `bin/` directory, plus the matching keybindings in
`modules/home-manager/hyprland/bindings.nix`. The t14 host inherits all
of this via `inputs.omarchy-nix.homeManagerModules.default` (line 43 of
`hosts/t14/home/omarchy.nix`).

**However, three runtime dependencies that those scripts invoke are
absent from `glats/omarchy-nix/modules/packages.nix`: `grim`,
`wl-clipboard`, and `tesseract`.** The scripts are deployed and on PATH,
but pressing the keybinding fails because the required binaries are
not in `$PATH`. This exploration confirms the gap and identifies the
minimum surface area to close it.

## Current State (verified by reading the workspace)

### What `glats/omarchy-nix` (upstream NixOS port) provides

The upstream `glats/omarchy-nix` (a fork of `basecamp/omarchy`) is a
full reimplementation, not a thin wrapper. It already includes:

**1. Bin scripts (in `bin/` of the omarchy-nix repo):**
- `omarchy-capture-screenshot` — region/windows/fullscreen/smart modes;
  satty editor; `grim` + `slurp` + `wl-copy` + `hyprpicker` for the
  frozen-overlay UX. CLI: `omarchy-capture-screenshot [mode] [processing]`.
  SHA `627eda0713b1e82d8e0ac4ddaf3c39477128495c`.
- `omarchy-capture-text-extraction` — region capture → tesseract OCR →
  wl-copy. SHA `cb0c62b5af1621774aef7f6958ffc91890214016`.
- `omarchy-capture-screenrecording` — gpu-screen-recorder wrapper.
- `omarchy-screenrecord` — menu-launcher variant.

**2. Deployment to PATH** (in
`modules/home-manager/default.nix` of omarchy-nix):

```nix
home.file = {
  ".local/share/omarchy/bin" = {
    source = executableBinDir;  # builds /bin with +x bit set
    recursive = true;
  };
  ...
};
home.sessionPath = [ "$HOME/.local/share/omarchy/bin" ];
xdg.configFile."environment.d/99-omarchy-path.conf".text = ''
  PATH=${config.home.homeDirectory}/.local/share/omarchy/bin:$PATH
'';
```

The `executableBinDir` derivation explicitly `chmod -R +x`s the bin
scripts because git doesn't preserve the +x bit.

**3. Hyprland keybindings** (in
`modules/home-manager/hyprland/bindings.nix`):

```nix
# Captures
", PRINT, Screenshot, exec, ${omarchyExec}/omarchy-capture-screenshot"
"ALT, PRINT, Screenrecording, exec, ${omarchyExec}/omarchy-menu screenrecord"
"SUPER, PRINT, Color picker, exec, pkill hyprpicker || hyprpicker -a"
...
"SUPER CTRL, C, Capture menu, exec, ${omarchyExec}/omarchy-menu capture"
```

`omarchyExec` resolves to `~/.local/share/omarchy/bin/`.

**4. Capture submenu in `omarchy-menu`** — `omarchy-menu` in the
omarchy-nix fork (SHA `19a78ea7bf3fa63445500b2a254c1e53ddbfcdc2`,
11,122 bytes) wires `Capture` into the main `Trigger` menu with
Screenshot / Screenrecord / Text Extraction / Color picker options —
identical structure to the basecamp/omarchy version but with
nixpkgs-friendly paths.

**5. Packages already installed** by
`glats/omarchy-nix/modules/packages.nix` (line 50 onwards):

```nix
# Screenshot and recording
satty
wf-recorder
gpu-screen-recorder
slurp
hyprland-preview-share-picker  # custom package
...
# Earlier in the same file (line 49-50):
hyprshot
hyprpicker
hyprsunset
```

So `slurp`, `satty`, `hyprshot`, `hyprpicker`,
`hyprland-preview-share-picker`, `wf-recorder`, and
`gpu-screen-recorder` are all already on t14's `$PATH` via the
upstream NixOS module.

### What is missing (the gap)

`grep`-ing `glats/omarchy-nix/modules/packages.nix` for the exact
dependency names used by the deployed scripts returns **zero matches**
for `grim`, `wl-clipboard`, and `tesseract`. Specifically:

| Dependency       | Used by script                | Present in upstream packages.nix? | Present on t14 today? |
|------------------|-------------------------------|------------------------------------|------------------------|
| `grim`           | `omarchy-capture-screenshot` (line 144: `grim -g "$SELECTION" "$FILEPATH"`) | NO | **NO — script fails** |
| `wl-copy`        | `omarchy-capture-screenshot`, `omarchy-capture-text-extraction` | NO (`wl-clipboard` package not declared) | likely NO |
| `tesseract`      | `omarchy-capture-text-extraction` (line 21: `tesseract stdin stdout --oem 1 --psm 6 -l eng --dpi 300 ...`) | NO | **NO — OCR script fails** |
| `tesseract-data-eng` | OCR data files (`-l eng`) | NO | **NO** |
| `jq`             | Used in `JQ_MONITOR_GEO` and `get_rectangles` | YES (line 88 of omarchy-nix packages.nix) | YES |
| `hyprpicker`     | frozen-overlay effect | YES | YES |
| `slurp`          | region selection | YES | YES |
| `satty`          | post-capture editor | YES | YES |
| `hyprshot`       | NOT used by current scripts (legacy) | YES (vestigial) | YES |
| `notify-send`    | post-capture notification | YES (`libnotify`) | YES |

**Result:** the keybinding exists, the script is deployed, the
notification icon is set, the editor is installed — but the core
capture binary (`grim`) and the OCR toolchain (`tesseract` +
`tesseract-data-eng`) and the clipboard binary (`wl-copy`) are all
absent. The user can press PRINT and the script starts, but it errors
out at `grim -g` before the `slurp` selection is even shown.

### What the local `nixos-hosts` repo contributes

`modules/base/profiles/base.nix` (line 110) installs `flameshot`
unconditionally. This is a MATE-friendly X11 screenshot tool and
**does not help t14**:

- No Hyprland keybinding calls `flameshot` in this repo.
- `home-linux/mate.nix` configures a `flameshot` autostart, but
  `home-linux/mate.nix` is explicitly **excluded** from t14's HM
  import list (line 21 of `hosts/t14/home/omarchy.nix`).
- `darwin/homebrew.nix` adds `flameshot` to homebrew — irrelevant for
  Linux.

So flameshot is dead weight on t14. The MATE `mate-screenshot`
config in `home-linux/mate.nix` (line 221) is also MATE-only.

`modules/desktop/fonts.nix` and other desktop modules have no
screenshot content.

### Workspace files relevant to this change

| File | Role |
|------|------|
| `flake.nix` | Pins `omarchy-nix` (the upstream NixOS port). Line 19-23. |
| `hosts/t14/default.nix` | t14 NixOS entry; imports `inputs.omarchy-nix.nixosModules.default`. |
| `hosts/t14/home/omarchy.nix` | t14 HM entry; imports `inputs.omarchy-nix.homeManagerModules.default`. |
| `hosts/t14/home/default.nix` | t14 Hyprland overlays (monitors, input, looknfeel, hyprlock, hyprsunset). |
| `hosts/t14/home/hypr/*.nix` | Per-host Hyprland fragments. |
| `modules/base/packages.nix` | Aggregates profiles → systemPackages. |
| `modules/base/profiles/base.nix` | Base profile: includes `flameshot` (MATE-style, no Hyprland integration). |
| `modules/base/profiles/{mate,gnome,dev,media,virt,browsers}.nix` | Other profiles, mostly MATE-specific. |
| `home-linux/` | HM modules for Linux hosts (mostly MATE; not used by t14). |
| `inputs.omarchy-nix` (flake input) | Upstream `glats/omarchy-nix` fork. Provides the bin scripts, keybindings, and omarchy-menu — but NOT the runtime deps `grim`, `wl-clipboard`, `tesseract`. |

## What `basecamp/omarchy` (Arch Linux) provides for reference

The Arch Linux upstream (which the user wants to mirror) has the
identical UX, exposed via four mechanisms:

**1. Packages** (`install/omarchy-base.packages` lines 50, 134, 137-138):
```
grim
hyprpicker
satty
slurp
tesseract
tesseract-data-eng
wl-clipboard
hyprland-guiutils
hyprland-preview-share-picker
```

**2. Hyprland keybindings** (`default/hypr/bindings/utilities.lua`):
```lua
o.bind("PRINT", "Screenshot", "omarchy-capture-screenshot")
o.bind_menu("ALT + PRINT", "Screenrecording", "screenrecord")
o.bind("SUPER + PRINT", "Color picker", "pkill hyprpicker || hyprpicker -a")
o.bind("SUPER + CTRL + PRINT", "Extract text (OCR) from screenshot", "omarchy-capture-text-extraction")
o.bind_menu("SUPER + CTRL + C", "Capture menu", "capture")
```

**3. Capture script** (`bin/omarchy-capture-screenshot`, SHA
`572330f78df65da93151cd89b36e2071c0d8334f`):
- Modes: `smart` (default, click any window or output), `region`
  (slurp region), `windows` (slurp over window/output rects),
  `fullscreen` (focused monitor geometry).
- Processing: `slurp` (save + clipboard + edit notification) or
  `copy` (clipboard only).
- Env vars: `OMARCHY_SCREENSHOT_DIR` (default `XDG_PICTURES_DIR` or
  `$HOME/Pictures`), `OMARCHY_SCREENSHOT_EDITOR` (default `satty`).
- Editor integration: `satty --filename ... --output-filename ...
  --actions-on-enter save-to-clipboard --save-after-copy --copy-command
  'wl-copy'`.
- Frozen-overlay trick: `hyprpicker -r -z` runs in background while
  `slurp` collects geometry; cleanup trap kills hyprpicker after
  `grim` captures.
- Hyprland geometry workaround: `JQ_MONITOR_GEO` accounts for
  portrait/transformed displays by swapping width/height when
  transform is 1 or 3.
- Smart-mode logic: if `slurp` returns a tiny rectangle
  (`L*W < 20`), fall back to the enclosing window/output.

**4. OCR script** (`bin/omarchy-capture-text-extraction`):
- Slurp selection → `grim` to stdout → `tesseract` with `--oem 1
  --psm 6 --dpi 300 -l "${OMARCHY_OCR_LANGS:-eng}"` → wl-copy.

**5. Mako notification customization** (`default/mako/core.ini`):
```
[summary~="Screenshot copied & saved"]
max-icon-size=80
format=<b>%s</b>\n%b
```
Larger icon and bold title for the post-capture notification, with an
action button that opens satty for editing.

**6. Capture submenu** in `bin/omarchy-menu` (`show_capture_menu`):
Screenshot / Screenrecord / Text Extraction / Color picker. Wired
into the `Trigger` menu.

**7. Migration scripts** (only relevant if we ever sync to a newer
Arch release):
- `migrations/1752955912.sh`: "Install satty for the new screenshot flow"
- `migrations/1760724934.sh`: "Add packages for updated
  omarchy-capture-screenshot" → `omarchy-pkg-add grim slurp`

These confirm the Arch maintainers also had to wire up `grim` and
`slurp` as a discrete step — Arch had `satty` already but the
capture flow was a separate concern.

## Affected Areas

- `flake.nix` — pin / unpin the upstream `omarchy-nix` input if a
  newer commit ships the missing packages. Otherwise no change.
- `hosts/t14/default.nix` — possibly add `systemPackages` overrides
  or a t14-specific NixOS module to add `grim`, `wl-clipboard`,
  `tesseract`, `tesseract-data-eng` to the system.
- `hosts/t14/home/omarchy.nix` — the cleanest place to add
  `home.packages = [ pkgs.grim pkgs.wl-clipboard pkgs.tesseract
  pkgs.tesseract-data-eng ]` because the upstream HM module is
  imported here and t14 already controls its HM list explicitly.
- `modules/base/profiles/base.nix` — optional: drop `flameshot` (line
  110) since it's unused on t14. Out of scope unless we want to
  tighten the base profile.
- `modules/base/packages.nix` — no change required; profiles
  compose the system packages.

## Approaches

### Approach A: Add missing packages to t14's home-manager (minimal patch)

Add `home.packages = with pkgs; [ grim wl-clipboard tesseract
tesseract-data-eng ];` to `hosts/t14/home/omarchy.nix`. The scripts
and keybindings are already in place from the upstream
`glats/omarchy-nix` module; only the runtime dependencies are
missing.

- Pros:
  - Smallest possible diff (one `home.packages` block, ~5 lines).
  - T14 owns the override explicitly; no upstream fork needed.
  - Matches the existing pattern of t14 layering overlays on top of
    omarchy-nix (see `hypr/*.nix` overlays).
  - Easy to remove or extend if upstream omarchy-nix eventually
    adds the packages.
- Cons:
  - Doesn't help any future host that imports the same upstream
    module; each host would need to repeat the override.
  - `grim` is technically a "system" tool (used by Hyprland's
    `exec` from `~/.config/hypr/bindings.conf`, although in our case
    the script invokes it). `home.packages` is fine for user
    invocations.
- Effort: **Low** (~5 LOC + `nix flake check`).

### Approach B: Patch upstream `glats/omarchy-nix` to add the packages

Add `grim`, `wl-clipboard`, `tesseract`, `tesseract-data-eng` to
`glats/omarchy-nix/modules/packages.nix` and bump the flake input.
Ships the fix for every consumer of the upstream module.

- Pros:
  - Fixes the gap for the entire NixOS community using the
    `glats/omarchy-nix` input.
  - Matches what the Arch upstream already does.
- Cons:
  - Requires a PR upstream and a flake.lock bump.
  - Slower feedback loop (PR review + flake update).
  - AGENTS.md note: "github.com/glats/omarchy-nix | Full clone &
    push access — changes involving this repo can be committed and
    pushed directly" — so this is feasible, but still a separate
    change/PR outside this repo.
- Effort: **Medium** (PR + flake bump + rebuild).

### Approach C: Create a reusable module in the local repo

Add `modules/features/screenshot.nix` (or `home-linux/screenshot.nix`)
that exports a `my.screenshot.enable` option and adds the packages.
Both t14 and any future host that wants the same feature can opt in
without copy-pasting the package list.

- Pros:
  - Reusable across hosts.
  - Self-documenting (one module describes the whole feature).
  - Aligns with the project's profile/feature module structure
    (e.g., `modules/features/services/xrdp.nix`).
- Cons:
  - More boilerplate than Approach A for a single-host fix.
  - Slightly more risk of over-engineering (the t14 host is the
    only one using omarchy right now).
- Effort: **Medium** (~30-50 LOC: new file + import in t14).

### Approach D: Submit the upstream `glats/omarchy-nix` PR AND add
local t14 packages as a defensive workaround

The upstream change may take time to merge. Until then, t14 can add
the packages locally so the feature works today.

- Pros:
  - Belt-and-suspenders: works immediately, and the fix propagates
    upstream.
- Cons:
  - Two changes to land in sync.
  - Risk of forgetting to remove the local override once upstream
    lands.
- Effort: **Medium-High** (PR + local override + cleanup tracking).

## Recommendation

**Approach A** for the immediate fix, with **Approach B** as a
follow-up to ship the fix upstream.

Justification:

1. The scripts and keybindings are already on disk. The user is one
   `home.packages` line away from working screenshots.
2. T14 already owns its HM import list explicitly (see
   `hosts/t14/home/omarchy.nix` lines 38-89) and uses `lib.mkForce`
   to neutralize conflicts with upstream defaults. Adding four
   packages fits the established t14 overlay pattern.
3. The alternative (Approach C) is over-engineered for a one-host,
   one-feature fix; we'd be adding an option to a project that
   currently has zero opt-in feature flags at the `my.*` namespace
   for Hyprland-specific capabilities.
4. Approach B is right as a follow-up. The user has direct push
   access to `glats/omarchy-nix` per AGENTS.md. After Approach A
   lands locally, we can open a small PR upstream that mirrors the
   same package additions and bump the flake input. That cleans up
   the local override.
5. The local `flameshot` install (in
   `modules/base/profiles/base.nix` line 110) is dead weight on
   t14 — but that's a separate cleanup, out of scope for this
   change.

The exact patch for Approach A is:

```nix
# hosts/t14/home/omarchy.nix
{
  # ... existing config ...
  home.packages = with pkgs; [
    # Screenshot toolchain — required by the omarchy-capture-*
    # scripts deployed by inputs.omarchy-nix. The upstream
    # glats/omarchy-nix/modules/packages.nix ships satty, slurp,
    # hyprshot, hyprpicker, wf-recorder, gpu-screen-recorder, and
    # hyprland-preview-share-picker, but is missing the core
    # screenshot binary (grim), the clipboard tool (wl-copy), and
    # the OCR toolchain (tesseract + tesseract-data-eng). All
    # three are dependencies of the PRINT / SUPER+PRINT /
    # SUPER+CTRL+PRINT / SUPER+CTRL+C bindings defined in
    # inputs.omarchy-nix's modules/home-manager/hyprland/bindings.nix.
    grim
    wl-clipboard
    tesseract
    tesseract-data-eng
  ];
}
```

(Implementation needs `pkgs` in the function args — already in scope
on line 31-35 of the existing file.)

## Risks

- **Upstream drift**: if `glats/omarchy-nix` upstream eventually
  adds `grim`/`wl-clipboard`/`tesseract` to its packages list, the
  local override becomes redundant. Mitigation: keep the upstream
  PR in flight, and remove the local `home.packages` block when
  the flake input bumps past that commit.
- **Editor default drift**: `omarchy-capture-screenshot` defaults
  to `satty` and `OMARCHY_SCREENSHOT_EDITOR` is overridable. t14
  users who don't want satty (heavy GTK app) can set
  `OMARCHY_SCREENSHOT_EDITOR=swappy` or `gimp` in their shell
  init. No risk to the default flow.
- **OCR language pack**: the script hardcodes `-l eng` in the
  omarchy-nix fork (line 21 of `bin/omarchy-capture-text-extraction`),
  while the basecamp/omarchy version uses
  `-l "${OMARCHY_OCR_LANGS:-eng}"`. The fork silently dropped the
  env var override. Out of scope for this change; flag in
  proposal as a known upstream divergence.
- **Transform-aware geometry**: the script's `JQ_MONITOR_GEO`
  block handles rotated displays. T14 panel is landscape 1920x1080
  at scale=1 — no transform — so this is correct on first use, no
  special handling needed.
- **Slurp cancellation**: the script's `pkill slurp && exit 0`
  pattern (line 21) means pressing PRINT twice rapidly cancels the
  selection. Correct UX, but worth documenting.

## Ready for Proposal

Yes. The exploration has identified the precise gap (three missing
runtime packages), the precise fix location (one `home.packages`
block in `hosts/t14/home/omarchy.nix`), and a clear follow-up
(upstream PR to `glats/omarchy-nix`).

The orchestrator should tell the user:

> Found the screenshot feature. The upstream `glats/omarchy-nix`
> module (the NixOS port) already ships the capture scripts and
> Hyprland keybindings, but is missing three runtime dependencies:
> `grim`, `wl-clipboard`, and `tesseract` + `tesseract-data-eng`.
> The fix is a 5-line `home.packages` block in
> `hosts/t14/home/omarchy.nix`. Recommend doing this locally and
> then submitting an upstream PR to `glats/omarchy-nix` to land
> the same packages there.

Proceed to `sdd-propose`.

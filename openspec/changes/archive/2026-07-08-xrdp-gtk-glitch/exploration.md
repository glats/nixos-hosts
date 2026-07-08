## Exploration: xrdp GTK Graphical Glitch — MATE Panel + GTK Apps Disappearing or Turning Black

### Current State

Both `rog` (NVIDIA GTX 1050, desktop+server) and `thinkcentre` (headless) run MATE desktop via xrdp. Users connect through RDP clients (Remmina, xfreerdp) to these hosts. The observed symptom is that GTK applications and the MATE panel start disappearing or turning black during xrdp sessions.

The rendering stack for xrdp sessions on both hosts is:

```
xrdp-sesman -> Xorg (virtual, no GPU) -> xrdp-mate-session launcher 
  -> mate-session-manager -> marco (window manager, compositing=OFF)
  -> picom (external compositor, backend=xrender, vsync=true)
  -> GTK apps (Materia-dark-compact theme via gtk-engine-murrine)
```

### Root Cause Analysis

**The external compositor picom is incompatible with xrdp's virtual X11 sessions.**

A documented, open issue exists: [yshui/picom#1433](https://github.com/yshui/picom/issues/1433) — "Picom + xrdp unfocused windows disappear" — where all windows except the focused one disappear when picom runs in xrdp sessions. The issue report confirms: `xrender` backend, `unredir-if-possible = false` does NOT help, and no errors appear in logs.

This is a **fundamental incompatibility** between an external compositor and xrdp's frame buffer management. xrdp sessions run via Xorg without GPU hardware acceleration — everything is software rendering via llvmpipe/softpipe. picom's GLX and XRender backends have documented software rendering issues (picom#1030, #1218):
- Windows contents stop updating or are not rendered at all
- `xrender` backend with software rendering can drop frame updates entirely
- Screen regions fail to repaint correctly

Additionally, picom's `vSync = true` setting in an xrdp session may trigger additional rendering synchronization problems since there is no hardware swap control available.

**Why marco compositing was disabled:** The dconf lock at `modules/base/dconf.nix` sets `compositing-manager = false` with a user lock. This was likely configured for the NVIDIA proprietary driver on rog, which does not support DRI3. As the ArchWiki notes: "marco does not support vertical synchronization via OpenGL [with NVIDIA proprietary], which may cause video tearing with enabled compositing." picom was introduced as the replacement compositor for direct-console sessions.

**However**, marco's built-in compositor (`compositor-xrender.c`) uses XRender directly and is designed to work in software rendering mode — exactly what xrdp provides. In xrdp sessions, marco compositing would work correctly and provide shadows, transparency, and tear-free rendering without conflicting with the virtual X server.

### Affected Areas

| File | Role | Change Needed |
|------|------|---------------|
| `hosts/rog/home/modules.nix` (line 9) | Imports picom.nix for rog | Remove picom import |
| `hosts/thinkcentre/home/modules.nix` (line 9) | Imports picom.nix for thinkcentre | Remove picom import |
| `modules/base/dconf.nix` (lines 8-23) | Locks marco compositing to false | Remove lock, set to true |
| `home-linux/picom.nix` | Defines picom configuration | Keep for future non-xrdp hosts |

### Approaches

#### 1. Approach A: Remove picom, enable marco compositing (Recommended)
- Remove `../../../home-linux/picom.nix` from both rog and thinkcentre home module lists
- Remove the dconf lock on `compositing-manager` and set it to `true`
- marco's built-in xrender compositor handles shadows/transparency in software rendering mode
- Pros: Simplest fix, definitive root cause resolution, fewer moving parts
- Cons: On rog, direct HDMI console sessions lose picom's shadows/transparency. marco compositing may have minor tearing with NVIDIA proprietary drivers on direct console (a separate and rare use case for these hosts)
- Effort: **Low** — 3 files changed, ~10 lines total

#### 2. Approach B: Conditional picom via xrdp-aware wrapper
- Create a wrapper script that exits picom when `$XRDP_SESSION=1`
- Override `services.picom.package` to use the wrapper
- Remove dconf lock, enable marco compositing (marco takes over in xrdp sessions)
- Pros: Preserves picom for rare direct console use on rog
- Cons: More complex, wrapper needs to handle systemd unit lifecycle, picom service still started and immediately killed in xrdp (noise in logs)
- Effort: **Medium** — 5 files changed, new wrapper package

#### 3. Approach C: Disable compositing entirely in xrdp sessions
- Kill picom in the xrdp session preamble (`modules/features/services/xrdp.nix`)
- Keep current dconf lock (no compositing at all in xrdp)
- Pros: Minimal change, only modifies xrdp launcher
- Cons: Users lose shadows and transparency entirely. The graphical glitch is fixed but the desktop looks flat/dated.
- Effort: **Low** — 1 file changed

### Recommendation

**Approach A** — Remove picom from both rog and thinkcentre, and enable marco's built-in compositing.

**Rationale:**
1. Both hosts are primarily (thinkcentre: exclusively) accessed via xrdp. The direct console use case is rare.
2. marco's built-in compositor uses XRender and works correctly in software rendering — no GPU needed.
3. picom is the root cause of the glitch; removing it is the definitive fix.
4. If direct console compositing issues arise on rog (NVIDIA tearing), that is a separate, minor concern that can be addressed later with a conditional approach.

**Fallback:** If marco compositing causes tearing on rog's HDMI console, revisit with Approach B (conditional wrapper) for rog only.

### Implementation Plan

1. Remove `../../../home-linux/picom.nix` from `hosts/rog/home/modules.nix` and `hosts/thinkcentre/home/modules.nix`
2. In `modules/base/dconf.nix`:
   - Remove the dconf lock block (lines 12-22)
   - Replace with a simpler `compositing-manager = true` setting (no lock needed)
3. Verify: `nix flake check --no-build`

### Risks

- **Low risk**: marco compositing on rog's HDMI direct console may have minor tearing with NVIDIA proprietary driver 580.legacy. This is a rare use case and can be addressed separately if reported.
- **No risk to thinkcentre**: thinkcentre is headless and exclusively xrdp-accessed. marco compositing will work correctly.
- **picom.nix file remains**: The file stays in the repo for potential future non-xrdp hosts. Only imports are removed.

### Ready for Proposal

Yes — the root cause is clearly identified (picom + xrdp incompatibility, documented upstream), the fix is straightforward, low-risk, and affects only 3 files.

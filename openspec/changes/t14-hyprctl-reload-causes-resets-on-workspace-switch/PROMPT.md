# SDD Session Prompt — t14-workspace-switch-resets

**For**: New SDD session (do NOT execute in this session)
**Save to**: Engram `sdd/t14-workspace-switch-resets/preflight` + openspec `openspec/changes/t14-workspace-switch-resets/`
**Predecessor**: `t14-hyprctl-reload-causes-resets-on-workspace-switch` (this session — partially successful, waybar still crashes)

---

## SDD Session Preflight

### Change: t14-workspace-switch-resets

On the T14 laptop (Hyprland 0.55 + Omarchy + 3 external monitors + eDP-1), switching
workspaces with Super+1/2/3 causes waybar to **crash and restart** (disappear → reappear,
PID changes). This is a real process crash, not a visual flicker or layer-shell redraw.

The prior SDD session (t14-hyprctl-reload-causes-resets-on-workspace-switch) made progress
but did NOT fully resolve the crash. Three confirmed fixes were applied and should be kept.
The remaining crash is in waybar's `hyprland/workspaces` IPC module.

### Execution Mode
- **guided** (auto-chain phases, pause before apply)

### Artifact Store
- **hybrid** (Engram + openspec)

### Delivery
- **no-pr** (commit directly to master/main on both repos)

### Review Budget
- **standard** (nix flake check, format-nix, grep basics)

---

## ⚠️ CRITICAL: REVALIDAR TODO — NO ASUMIR NADA

**Toda la información en este documento es meramente informativa.** El contenido refleja
lo que se observó, intentó y aprendió en sesiones anteriores, pero PUEDE estar desactualizado,
ser incorrecto o no aplicar al estado actual del sistema.

La próxima sesión SDD DEBE:

1. **Verificar el estado real del sistema** — no confiar en lo que dice este documento:
   - `git log --oneline origin/master -20` para confirmar qué commits están realmente deployed
   - `grep` en los archivos actuales (`hyprland.conf`, `waybar/config`, `monitor-lid-validator.sh`)
   - `pgrep waybar`, `systemctl --user status monitor-lid-validator` para ver procesos vivos
   - `waybar --version` y `readlink -f /etc/profiles/per-user/glats/bin/waybar` para el binario

2. **No repetir experimentos fallidos** sin evidencia nueva — los intentos A-D documentados
   abajo fallaron bajo condiciones específicas. Si esas condiciones cambiaron, re-evaluar.

3. **Cuestionar las hipótesis** — la hipótesis del crash en IPC event handler es eso: una
   hipótesis. Puede ser incorrecta. Validar con datos nuevos (socat, strace, core dumps).

4. **Leer los archivos reales**, no confiar en extractos de este documento.

---

## RELACIÓN CON t14-hdm-migration-v2

Hay OTRO cambio SDD en progreso: **`t14-hdm-migration-v2`** (`openspec/changes/t14-hdm-migration-v2/`).
Este cambio reemplaza completamente el stack de monitores de la T14 (validator daemon, hyprlang
conditionals, bindls, settings.conf, udev drop-in) con HyprDynamicMonitors v1.4.0.

### ¿HDM arregla el crash de waybar?

**NO directamente.** HDM gestiona monitores (posiciones, lid, dock/undock). El crash de waybar
está en el módulo `hyprland/workspaces` de waybar, que se comunica con Hyprland vía IPC para
información de workspaces — independiente de cómo se gestionen los monitores.

**PERO hay interacciones que la exploración DEBE verificar:**

1. **HDM elimina el validator daemon** → menos `hyprctl keyword monitor` calls → menos
   eventos IPC de Hyprland → ¿menos crashes de waybar? (especulativo, requiere prueba)

2. **HDM ya incluye el filtro w > 3** (BUG 6 fix) → uno de nuestros 3 fixes ya está
   contemplado. Si HDM ya está deployed, el fix 2 (workspace filter) es redundante.

3. **HDM usa `hyprctl keyword monitor` nativo** (no `hyprctl reload`) → elimina flicker
   de reloads. Pero el crash de waybar en switch de workspace no es por reload.

4. **R5 en la exploración de HDM**: "Workspace filter breaks waybar monitor module —
   waybar is unaffected". Esto evaluó si el filtro ROMPE waybar (no lo rompe), pero NO
   consideró el crash preexistente de waybar.

### Recomendación para la próxima sesión

Antes de empezar el SDD de waybar, verificar el estado de HDM:

```bash
ls openspec/changes/t14-hdm-migration-v2/tasks.md
git log --oneline origin/master | grep -i hdm
```

- **Si HDM NO está deployed**: aplicar el fix de waybar primero (más simple, menos
  dependencias), luego HDM encima.
- **Si HDM YA está deployed**: verificar si waybar sigue crasheando. Si HDM eliminó
  el validator daemon y los reloads, el crash podría ser menos frecuente o haber
  desaparecido. Si persiste, aplicar fix de waybar sobre HDM.
- **Si HDM está en progreso (tasks.md existe pero no apply)**: coordinar — los cambios
  de HDM y waybar tocan archivos distintos, se pueden aplicar en cualquier orden.
  El PROMPT.md de HDM está en `openspec/changes/t14-hdm-migration-v2/PROMPT.md`.

### Archivos que ambos cambios tocan

| Archivo | HDM | Waybar |
|---------|-----|--------|
| `hosts/t14/home/hypr/monitors.nix` | Modifica (strip extraConfig, source directive) | PRESERVA fix 2 (w>3 filter) |
| `hosts/t14/home/default.nix` | Modifica (remove daemon/activation) | No toca |
| `hosts/t14/home/scripts/monitor-lid-validator.sh` | ELIMINA | PRESERVA fix 1 |
| `omarchy-nix/config/waybar/config` | No toca | Modifica (workspace module) |
| `omarchy-nix/bin/omarchy-hyprland-monitor-watch` | Documenta race | PRESERVA fix 3 |
| `flake.nix` | Agrega HDM input | Limpia waybar-src input |

**No hay conflicto** — los cambios son ortogonales. El orden no importa, pero si HDM
elimina el validator, el fix 1 se vuelve irrelevante (el archivo se borra).

---

## REPOSITORY CONTEXT

- **nixos-hosts** (`github.com/glats/nixos-hosts`): Multi-host NixOS + Home Manager config.
  Workspace: `/home/glats/.nixos`. T14 is `hosts/t14/`. Stack: NixOS flakes, Omarchy (Hyprland),
  sops-nix, nixos-hardware. Branch: `master`.
- **omarchy-nix** (`github.com/glats/omarchy-nix`): User OWNS this repo (full push access).
  Contains waybar config, Hyprland autostart, monitor-watch daemon, theme system. Branch: `main`.
- **Patterns**: `nixos-build` for switching, `format-nix` for formatting, `nix flake check --no-build`
  for validation. Home Manager integrated via `modules/base/home-manager.nix`.

---

## WHAT WAS FIXED (KEEP THESE)

The prior session identified and fixed three contributing factors. These changes are LIVE on
origin/master and origin/main. **DO NOT REVERT THEM** — they eliminated real problems, just
not the final crash.

### Fix 1 — Removed `hyprctl reload` from validator daemon
**Commit**: `b39d79f` (nixos-hosts)
**File**: `hosts/t14/home/scripts/monitor-lid-validator.sh:47`
**Change**: Deleted `hyprctl reload` from `apply()`.
**Why**: Monitor positions applied via `hyprctl keyword monitor` — reload unnecessary.
Reload re-parses entire Hyprland config, causing IPC disruption that can crash waybar.
**Status**: ✅ Confirmed working. Validator applies positions without reload.

### Fix 2 — Filtered workspace dual-binding
**Commit**: `b39d79f` (nixos-hosts)
**File**: `hosts/t14/home/hypr/monitors.nix`
**Change**: `workspaces` → `builtins.filter (w: w > 3) workspaces` in `mkWorkspaceRules`.
**Why**: Hyprland 0.55 merges workspace rules (PR #14217, `mergeLeft`). Binding workspace 1
to BOTH `desc:AOC 24P1W1...` (mkWorkspaceRules) AND `eDP-1` (extraConfig) created hybrid
rules that cause `destroyworkspace>>` IPC events when the target monitor doesn't exist.
**Result**: Workspaces 1-3 now ONLY bound to eDP-1 (via extraConfig). Workspaces 4-20
distributed mod-3 across external monitors. No dual binding.
**Status**: ✅ Confirmed working. `grep "workspace =" hyprland.conf` shows clean bindings.

### Fix 3 — Removed `monitoradded>>` reload from omarchy
**Commit**: `b2fa795` (omarchy-nix)
**File**: `bin/omarchy-hyprland-monitor-watch`
**Change**: Deleted the `monitoradded>>` → `hyprctl reload` handler.
**Why**: Second reload source. T14 daemon polling handles monitor changes without reload.
**Status**: ✅ Confirmed working.

### Fix 4 — Waybar stderr capture (diagnostic, optional)
**Commit**: `b2fa795` (omarchy-nix)
**File**: `modules/home-manager/hyprland/autostart.nix:14`
**Change**: `uwsm-app -- waybar` → `uwsm-app -- waybar 2>>$HOME/.cache/waybar-stderr.log`
**Status**: ⚠️ Not working as intended. `uwsm-app` wraps waybar in a transient systemd scope,
so the shell redirect doesn't propagate. Log file exists but contains Ghostty output, not
waybar crash logs. Can be removed or fixed.

---

## WHAT WAS TRIED AND FAILED (DO NOT REPEAT)

### Attempt A — `wlr/workspaces` module
**Commit**: `0eb57ea` (omarchy-nix) + `83f8c9c` (nixos-hosts)
**What**: Changed waybar module from `hyprland/workspaces` to `wlr/workspaces`.
**Result**: Waybar showed `Unknown module: wlr/workspaces`. nixpkgs waybar v0.15.0 is
compiled WITHOUT the wlr/workspaces module. **Non-viable.**

### Attempt B — waybar-git overlay (PR #5013)
**Commits**: `efe2003` to `ae6de62` (nixos-hosts)
**What**: Built waybar from master (`github:Alexays/Waybar`, commit `0594574`) which includes
PR #5013 ("fix(hyprland/workspaces): adapt dispatch commands for Lua IPC protocol").
**Result**: **INTRODUCED REGRESSION.** The master-built waybar crashes ON STARTUP (within seconds)
even with minimal config (`"format": "{name}"`, no on-click, no icons, no persistent-workspaces).
The original nixpkgs waybar v0.15.0 survives startup but crashes on workspace switch.
**Reverted** in `7745e34`. **Do NOT build waybar from master again — it's worse.**

KEY FINDING from the side-by-side test:
- **Original waybar v0.15.0** (nixpkgs): STABLE on startup, survives 15s+ idle. Crashes on workspace switch.
  Binary: `/nix/store/hzr744bdnmazhdd9vz9c8n2i8wdj8cfs-waybar-0.15.0/bin/waybar`
- **waybar master (PR #5013)**: CRASHES WITHIN SECONDS of startup, even idle.
  Binary: `/nix/store/505mijyxhqsg1m4n8681kcyg4lrhcssn-waybar-0.15.0-0594574/bin/waybar`

### Attempt C — Remove persistent-workspaces from waybar config
**Commit**: `a316ce9` (omarchy-nix) + `6914e55` (nixos-hosts)
**What**: Removed `persistent-workspaces` block from `hyprland/workspaces` config.
**Result**: Still crashed. Persistent workspaces NOT the trigger.

### Attempt D — Minimal waybar config
**Commit**: `f6b5a93` (omarchy-nix) + `b31ae26` (nixos-hosts)
**What**: Reduced `hyprland/workspaces` to just `{"format": "{name}"}`. No on-click, no icons.
**Result**: Still crashed (even with original v0.15.0 binary). The `hyprland/workspaces` module
crashes just from receiving IPC events — no config tweak helps.

---

## CURRENT STATE (AS OF SESSION END)

### Waybar
- **Binary**: Original nixpkgs waybar v0.15.0 (stable on startup)
- **Config**: Minimal `hyprland/workspaces` → `{"format": "{name}"}` (deployed from omarchy-nix f6b5a93)
- **Behavior**: STABLE at idle. CRASHES on workspace switch (Super+1/2/3/4).
- **Crash evidence**: PID changes after switch. `pgrep waybar` shows new PID.

### Hyprland workspace rules (verified correct)
```
workspace = 1, monitor:eDP-1, default:true, persistent:true
workspace = 2, monitor:eDP-1, persistent:true
workspace = 3, monitor:eDP-1, persistent:true
workspace = 4, monitor:desc:AOC 24P1W1..., default:true, persistent:true
workspace = 5, monitor:desc:Lenovo..., default:true, persistent:true
workspace = 6-20... (mod-3 distribution across 3 external monitors)
```
No dual-binding. Clean.

### Validator daemon
- **Running**: `systemctl --user status monitor-lid-validator` shows active
- **No hyprctl reload**: Confirmed via `grep "hyprctl reload" ~/.local/bin/monitor-lid-validator.sh` → no match

### omarchy monitor-watch
- **No monitoradded reload**: Confirmed removed from omarchy-nix main

### Pending cleanup in nixos-hosts
- `flake.nix` still has unused `waybar-src` input (lines ~113-117). Safe to remove or ignore.
- `flake.lock` has been bumped multiple times for omarchy-nix. Current pin: `f6b5a93`.

---

## FEATURES TO PRESERVE

> **NOTA**: Si `t14-hdm-migration-v2` ya fue deployed, el stack de monitores es HDM,
> no el validator daemon. Verificar antes de asumir. La info abajo describe el estado
> post-fixes de esta sesión (b39d79f) — puede estar obsoleto.

### Monitor Layout (working, do NOT break)
Same as documented in `docs/t14-monitor-layout.md`. 3 external monitors + eDP-1.
Dead-zone fix (y=420) preserved. Lid-state conditional layout (hyprlang `if ENABLE_LAPTOP`)
preserved. **Si HDM está deployed**, el layout se maneja vía HDM profiles, no hyprlang
conditionals — verificar `hosts/t14/hdm/config.toml`.

### Workspace Distribution (working after fix 2)
| Monitor | Workspaces |
|---------|-----------|
| eDP-1 | 1, 2, 3 (persistent, default on 1) |
| AOC 24P1W1 (rotated) | 4, 7, 10, 13, 16, 19 |
| Lenovo G24-10 | 5, 8, 11, 14, 17, 20 |
| AOC 2470W | 6, 9, 12, 15, 18 |

### Other Preserved Settings (DO NOT TOUCH)
- `GDK_SCALE=1` — no HiDPI scaling
- `omarchy.greeter.*` — COMPLETELY SEPARATE (ReGreet login screen, different user)
- `omarchy.hyprland.lidSwitch.enable = false` — prevents dual-writer race
- UPower — already enabled via `power-profiles-daemon`

---

## ROOT CAUSE HYPOTHESIS

The crash is in waybar's `hyprland/workspaces` IPC event handler. When Hyprland 0.55
emits workspace events (e.g., `destroyworkspace>>`, `createworkspace>>`, `workspace>>`),
waybar v0.15.0's handler corrupts memory or accesses freed objects, causing SIGSEGV.

Evidence:
1. Crash happens on workspace SWITCH, not on startup or idle
2. Removing ALL config options (persistent-workspaces, on-click, format-icons) doesn't help
3. The trace log shows `Removing workspace 4`, `Creating workspace 1` just before crash
4. Waybar master (PR #5013) made it WORSE — crash on startup, not just on switch
5. The crash survives all three reload-source fixes — not a reload problem

The `destroyworkspace>>` events are emitted because Hyprland 0.55 re-evaluates workspace
assignments during switch, briefly destroying and recreating workspace objects. Waybar
can't handle the rapid create/destroy cycle.

---

## EXPLORATION PHASE REQUIREMENTS

The explore phase MUST investigate the following before proposing any approach:

### 1. Waybar IPC crash mechanism
- Read waybar source: `src/modules/hyprland/workspaces.cpp` and `workspace.cpp`
- Look for the IPC event handler that processes `destroyworkspace>>`, `createworkspace>>`
- Identify shared_ptr or raw pointer lifetime issues
- Check if any fix exists in waybar master BEYOND PR #5013 (which only fixed dispatch)

### 2. Hyprland 0.55 workspace event behavior
- Use `socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HIS/.socket2.sock` to capture
  real IPC events during a workspace switch on the T14
- Does Hyprland emit `destroyworkspace>>` → `createworkspace>>` in rapid succession?
- Can this be configured or suppressed?

### 3. Alternative workspace modules
- `sway/workspaces` — does Hyprland expose i3 IPC compatibility? Test on T14.
- `custom` module with `hyprctl` polling — ugly but stable
- `ext/workspaces` — does waybar v0.15.0 from nixpkgs support it? (Previously showed "Unknown module")
- Disable workspace display entirely — acceptable UX tradeoff?

### 4. Waybar build options
- Can waybar v0.15.0 from nixpkgs be patched (not full master) to fix just the IPC crash?
- Is there a specific commit between v0.15.0 and master that fixes the crash WITHOUT
  introducing the startup regression?
- `nixpkgs-waybar` unofficial flakes? Community overlays?

### 5. Workaround: systemd-managed waybar with auto-restart
- If crash is unavoidable, make it invisible: manage waybar via systemd with
  `Restart=always` + `RestartSec=0`. Waybar crashes → restarts instantly → user
  barely notices. Band-aid, not root cause fix.
- Requires changing waybar launch from `exec-once` to systemd user service.

---

## KNOWN ISSUES FROM THIS SESSION (TO VALIDATE)

### Issue 1 — waybar stderr capture broken
`uwsm-app -- waybar 2>>$HOME/.cache/waybar-stderr.log` doesn't work because `uwsm-app`
wraps waybar in a transient systemd scope. The redirect applies to the uwsm-app wrapper,
not the waybar process. **Validate**: use `systemd.exec` environment or wrapper script.

### Issue 2 — `wlr/workspaces` not compiled in nixpkgs waybar
`waybar -l debug` shows `Unknown module: wlr/workspaces`. nixpkgs waybar v0.15.0 is
compiled without this module. **Validate**: check nixpkgs waybar build flags.

### Issue 3 — waybar master regression
Building waybar from `github:Alexays/Waybar` commit `0594574` (May 2026, includes PR #5013)
causes INSTANT crash on startup. Something between v0.15.0 release and that commit broke
waybar on this Hyprland 0.55 + multi-monitor setup. **Validate**: bisect waybar commits
to find the exact breaking change, or find a commit that fixes the switch crash WITHOUT
the startup regression.

### Issue 4 — Ghostty output in waybar stderr log
`~/.cache/waybar-stderr.log` contains Ghostty terminal output, not waybar output.
The redirect is capturing wrong process. **Validate**: fix stderr capture.

### Issue 5 — `omarchy-toggle-waybar` as restart mechanism
When waybar crashes, something restarts it (PID changes). Candidate:
`omarchy-nix/bin/omarchy-toggle-waybar` (`pkill -f waybar || uwsm-app -- waybar`).
Bound to Super+Shift+Space. **Validate**: does this script run on crash, or does
Hyprland re-run exec-once?

---

## FILES TO MODIFY (for the fix, whatever it is)

| File | Action |
|------|--------|
| `hosts/t14/home/hypr/monitors.nix` | PRESERVE fix 2 (w>3 filter). May need workspace rule adjustment. |
| `hosts/t14/home/scripts/monitor-lid-validator.sh` | PRESERVE fix 1 (no reload). |
| `omarchy-nix/config/waybar/config` | Change or disable `hyprland/workspaces` module |
| `omarchy-nix/modules/home-manager/hyprland/autostart.nix` | Change waybar launch (systemd? different module?) |
| `omarchy-nix/bin/omarchy-hyprland-monitor-watch` | PRESERVE fix 3 (no monitoradded reload) |
| `overlays/linux.nix` (nixos-hosts) | REMOVE unused waybar-git code (if still present) |
| `flake.nix` (nixos-hosts) | REMOVE unused `waybar-src` input |

---

## RELEVANT CONTEXT FILES (READ THESE)

- `hosts/t14/home/scripts/monitor-lid-validator.sh` (71 lines) — validator daemon
- `hosts/t14/home/hypr/monitors.nix` (86 lines) — workspace rules + static monitor blocks
- `hosts/t14/home/default.nix` (106 lines) — systemd service, activation, udev
- `omarchy-nix/config/waybar/config` — waybar JSON config (currently minimal hyprland/workspaces)
- `omarchy-nix/modules/home-manager/hyprland/autostart.nix` — exec-once (waybar launch)
- `omarchy-nix/bin/omarchy-hyprland-monitor-watch` — socket2 event handler
- `omarchy-nix/bin/omarchy-toggle-waybar` — toggle script (possible restart mechanism)
- `docs/t14-monitor-layout.md` — monitor layout reference
- `openspec/specs/t14-monitor-layout/spec.md` (213 lines) — existing spec
- `openspec/changes/t14-hyprctl-reload-causes-resets-on-workspace-switch/` — full prior SDD artifacts:
  - `exploration.md` — two-pass exploration (22K)
  - `proposal.md` — approach 3+4 proposal
  - `spec.md` — delta specs (4 modified + 1 new requirement)
  - `design.md` — exact code diffs for 4 changes
  - `tasks.md` — 10 tasks across 3 phases
- Engram `sdd/t14-hyprctl-reload-causes-resets-on-workspace-switch/explore` (obs #439) — pass 2 with waybar crash hypothesis
- Engram `sdd/t14-hyprctl-reload-causes-resets-on-workspace-switch/proposal` (obs #441)
- Engram: session summaries #436 (prior session), #440 (this explore session), #455 (bugfix save)
- GitHub: waybar issues #4361, #4357, #5008, #5035; PRs #5013 (merged, dispatch fix), #5103 (unrelated tooltip-fix)
- GitHub: Hyprland PR #14217 (mergeLeft workspace rules)
- Git log: `git log --oneline ec0b228..7745e34` for this session's commits on nixos-hosts
- Git log (omarchy-nix): commits `b2fa795` through `f6b5a93` for this session's changes

---

## COMMIT CLEANUP NOTE

This session produced 8 commits on nixos-hosts master (`b39d79f` through `7745e34`).
Several are noise (waybar-git overlay + reverts, config experiments). Before the next
SDD apply phase, consider squashing the meaningful changes (b39d79f: validator + workspace
fixes) and dropping the waybar-git overlay commits. The omarchy-nix commits similarly
accumulated experimental config changes; the final state (`f6b5a93`: minimal config) plus
the monitor-watch fix (`b2fa795`) are what matter.

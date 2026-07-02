# SDD Session Prompt — t14-cleanup-hdm-waybar

**For**: New SDD session (do NOT execute in this session)
**Save to**: Engram `sdd/t14-cleanup-hdm-waybar/preflight` + openspec `openspec/changes/t14-cleanup-hdm-waybar/`
**Predecessors**: `t14-workspace-switch-resets` + `t14-hdm-migration-v2`

---

## SDD Session Preflight

### Change: t14-cleanup-hdm-waybar

Two prior SDD sessions applied partial fixes and left dirty commit history:

1. **t14-workspace-switch-resets**: Applied `ext/workspaces` + systemd waybar service. The waybar fix WORKS — PID stable across 20+ workspace switches. The real culprit was NOT waybar — it was `monitor-lid-validator` doing `hyprctl keyword monitor` every 2s (~1268 Hyprland modesets accumulated), causing visual flicker that looked like waybar restarting. The validator was manually stopped (`systemctl --user stop`) and flicker disappeared.

2. **t14-hdm-migration-v2**: HDM profiles fully designed (exploration, proposal, spec, design, tasks — all complete) but NEVER applied. HDM replaces the validator daemon entirely, which would eliminate the modeset flicker at the root.

This session must: apply the HDM migration, clean up the dirty commit history in both repos, and verify everything on T14 hardware.

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

Toda la información en este documento es meramente informativa. Refleja lo observado en sesiones anteriores pero PUEDE estar desactualizada. La próxima sesión DEBE:

1. Verificar el estado REAL del sistema:
   - `git log --oneline origin/master -30` — commits realmente deployed
   - `git log --oneline origin/main -10` — omarchy-nix (en `/home/glats/repos/omarchy-nix`)
   - `git status` en ambos repos — cambios uncommitted
   - `systemctl --user status monitor-lid-validator` — ¿sigue parado o lo reiniciaron?
   - `systemctl --user status waybar` — ¿activo? ¿PID estable?
   - `cat ~/.config/waybar/config | grep ext/workspaces` — ¿config activa?
   - `grep "waybar-src" flake.nix` — ¿ya eliminado?

2. Leer los archivos reales, no confiar en extractos de este documento.

3. Cuestionar las hipótesis — la info abajo es lo que se OBSERVÓ, no necesariamente la verdad.

---

## REPOSITORY CONTEXT

- **nixos-hosts** (`github.com/glats/nixos-hosts`): `/home/glats/.nixos`, branch: `master`
- **omarchy-nix** (`github.com/glats/omarchy-nix`): `/home/glats/repos/omarchy-nix`, branch: `main`. User OWNS this repo (full push access).

---

## WHAT WAS LEARNED (observations, not prescriptions)

1. **Waybar NUNCA crasheó con ext/workspaces**. PID se mantuvo estable en 20+ muestras durante switches de workspace (Super+1/2/3/4/5).

2. **El "reinicio" visual era Hyprland haciendo modesetting** por culpa del validator. `hyprctl keyword monitor` cada 2s → ~1268 modesets acumulados → redibuja toda la escena incluido waybar → parpadeo.

3. **Parar el validator eliminó el flicker inmediatamente**. `systemctl --user stop monitor-lid-validator` → cero parpadeo en workspace switches.

4. **systemd `Restart=always`** está configurado para waybar pero ni siquiera fue necesario — no hubo crashes.

5. **`StartLimitIntervalSec` va en `[Unit]`, no en `[Service]`** en systemd ≥ 252. T14 tiene systemd 260. El unit file actual tiene un warning: `Unknown key 'StartLimitIntervalSec' in section [Service]`.

6. **waybar-git desde master NO funciona**. HEAD (`0594574`, May 2026) crashea instantáneamente en startup. No hay commits posteriores. No construir desde master.

7. **`wlr/workspaces` no está compilado** en nixpkgs waybar. Requiere overlay con `-Dwlr=enabled`.

8. **`omarchy-toggle-waybar`** ahora usa `systemctl --user is-active/stop/start waybar` — verificado funcional.

---

## COMMIT AUDIT: omarchy-nix (main)

Working directory: `/home/glats/repos/omarchy-nix`

Estado al final de la sesión (verificar con `git log --oneline origin/main -15`):

```
c9f7554 fix(hypridle): override Restart to on-failure (corrected syntax)
76e25f4 feat(waybar): migrate to ext/workspaces, systemd service, remove hyprctl reload
f6b5a93 debug(waybar): minimal hyprland/workspaces config to isolate crash
a316ce9 fix(waybar): disable persistent-workspaces to debug crash
dc730dd revert(waybar): restore hyprland/workspaces — fix applied via waybar-git overlay
0eb57ea fix(waybar): switch hyprland/workspaces to wlr/workspaces for Hyprland 0.55 compat
b2fa795 fix(monitor-watch): remove monitoradded hyprctl reload, capture waybar stderr
3b42b9d fix(waybar): show LAN-disconnect icon when NM unmanages wlan0; space iwd-wifi widget
... (commits anteriores)
```

**Commits con cambios válidos que deben sobrevivir a la limpieza**:
- `76e25f4` — ext/workspaces config + systemd launch + toggle script + monitor-watch reload removal
- `c9f7554` — hypridle Restart fix (no relacionado con waybar)
- `b2fa795` — eliminó `monitoradded>> hyprctl reload` del monitor-watch (válido, pero `76e25f4` ya incluye esto)

**Commits de experimentos fallidos**:
- `f6b5a93`, `a316ce9`, `dc730dd`, `0eb57ea` — intentos de debug (minimal config, quitar persistent-workspaces, wlr/workspaces, revert)

**Archivos modificados por `76e25f4`** (el commit que contiene todo lo bueno):
- `config/waybar/config` — hyprland/workspaces → ext/workspaces
- `modules/home-manager/hyprland/autostart.nix` — pkill/uwsm-app → systemctl
- `bin/omarchy-toggle-waybar` — pgrep/pkill/uwsm-app → systemctl
- `bin/omarchy-hyprland-monitor-watch` — removido monitoradded>> hyprctl reload

---

## COMMIT AUDIT: nixos-hosts (master)

Working directory: `/home/glats/.nixos`

Estado al final de la sesión (verificar con `git log --oneline origin/master -30`):

```
551fea7 chore(flake): bump omarchy-nix for hypridle Restart=on-failure fix
f86b18a fix(opencode): apply failure-mode fit to NVIDIA NIM phases
7de121f feat(t14): add systemd user service for waybar, remove waybar-src
6e38d2a fix(opencode): remove kimi/glm-5.2 from SDD phases, apply failure-mode fit
013934d fix(opencode): use correct opencode-go/ prefix (not opencode/)
2fbf6f7 fix(opencode): restore opencode/ prefix to model refs in go-full/medium/light
7745e34 revert(overlay): remove waybar-git — PR #5013 introduced regression
b31ae26 fix(t14): minimal waybar hyprland/workspaces config
6914e55 fix(t14): disable waybar persistent-workspaces to isolate crash
ae6de62 fix(overlay): skip waybar version check in installCheckPhase
2c7092a fix(overlay): disable cava in waybar-git build
efe2003 feat(t14): add waybar-git overlay with Hyprland 0.55 workspace fix (PR #5013)
83f8c9c fix(t14): switch waybar to wlr/workspaces for Hyprland 0.55 compat
ec0b228 work
140ea91 chore(rog): remove unused git-credentials sops declaration
b225181 feat(gh-auth): wire github pat via sops for linux hosts
b39d79f fix(t14): remove hyprctl reload from monitor path, filter workspace dual-binding
... (commits anteriores)
```

**Commits con cambios válidos que deben sobrevivir a la limpieza**:
- `b39d79f` — eliminó `hyprctl reload` del validator + filtró workspace dual-binding (w>3)
- `7de121f` — systemd user service para waybar + removió `waybar-src` de flake.nix + bump omarchy-nix. ⚠️ Este commit tiene un BUG: `StartLimitIntervalSec` está en `[Service]` pero debe ir en `[Unit]` (systemd 260 da warning)
- `551fea7` — bump omarchy-nix para hypridle (no relacionado con waybar)
- `b225181`, `140ea91` — gh-auth + cleanup (no relacionado)
- Commits de opencode (`f86b18a`, `6e38d2a`, `013934d`, `2fbf6f7`) — no relacionados

**Commits de experimentos fallidos**:
- `83f8c9c` — wlr/workspaces attempt
- `efe2003` — waybar-git overlay (PR #5013)
- `2c7092a` — disable cava en waybar-git build
- `ae6de62` — skip version check en waybar-git
- `6914e55` — disable persistent-workspaces
- `b31ae26` — minimal waybar config
- `7745e34` — revert waybar-git overlay
- `ec0b228` — "work" (commit sin descripción clara)

**Cambios UNCOMMITTED** (verificar con `git status` y `git diff`):

| Archivo | Cambio |
|---------|--------|
| `hosts/t14/home/default.nix` | `StartLimitIntervalSec` + `StartLimitBurst` movidos de `[Service]` a `[Unit]` (fix del bug en `7de121f`) |
| `modules/base/nix.nix` | Timeouts más agresivos: `download-attempts=3`, `connect-timeout=5`, `fallback=true` |
| `shared/opencode/providers-base.nix` | Reformateo de función `activeProvider` |

---

## HDM MIGRATION STATE

El cambio `t14-hdm-migration-v2` tiene todos los artefactos SDD completos pero NUNCA fue aplicado:

- `openspec/changes/t14-hdm-migration-v2/exploration.md` — exploración completa
- `openspec/changes/t14-hdm-migration-v2/proposal.md` — alcance y approach
- `openspec/changes/t14-hdm-migration-v2/specs/` — delta specs
- `openspec/changes/t14-hdm-migration-v2/design.md` — diseño técnico con diffs exactos
- `openspec/changes/t14-hdm-migration-v2/tasks.md` — 15 tareas, 4 fases, TODAS `[ ]` (sin aplicar)
- `openspec/changes/t14-hdm-migration-v2/PROMPT.md` — prompt original de la sesión HDM

HDM reemplaza completamente el stack de monitores:
- Elimina `monitor-lid-validator.sh` (el daemon que causa los modesets)
- Elimina `seedHyprSettings` activation script
- Elimina `udev-settle.conf` drop-in
- Elimina hyprlang conditionals (`ENABLE_LAPTOP`)
- Reemplaza con profiles estáticos (TOML + hyprconfigs) manejados por el daemon HDM

**HDM mataría al validator** y por lo tanto eliminaría los modesets que causan el flicker de waybar. Las tareas 3.1 y 3.3 del HDM tasks.md explícitamente eliminan el validator.

---

## ARCHIVOS A PRESERVAR (cambios del fix de waybar — NO TOCAR)

Estos archivos contienen cambios funcionales del fix de waybar que deben sobrevivir a cualquier limpieza:

| Archivo (repo) | Contenido a preservar |
|----------------|----------------------|
| `omarchy-nix/config/waybar/config` | `ext/workspaces` en modules-left + bloque de configuración |
| `omarchy-nix/modules/home-manager/hyprland/autostart.nix` | `systemctl --user restart waybar \|\| systemctl --user start waybar` |
| `omarchy-nix/bin/omarchy-toggle-waybar` | `systemctl --user is-active/stop/start waybar` |
| `omarchy-nix/bin/omarchy-hyprland-monitor-watch` | Sin `monitoradded>> hyprctl reload` |
| `nixos-hosts/hosts/t14/home/default.nix` | `systemd.user.services.waybar` (con `Restart=always`) |
| `nixos-hosts/overlays/linux.nix` | Ya está limpio (sin waybar-git) |
| `nixos-hosts/hosts/t14/home/hypr/monitors.nix` | Filtro `w > 3` en línea 25 |
| `nixos-hosts/hosts/t14/home/scripts/monitor-lid-validator.sh` | Sin `hyprctl reload` en `apply()` |

---

## VERIFICATION GATES (post-cleanup)

```
nix flake check --no-build     # debe pasar
format-nix                     # todo limpio

grep "waybar-src" flake.nix                        → no match
grep -r "hyprctl reload" hosts/t14/                → no match
grep -r "monitor-lid-validator" hosts/t14/         → no match (HDM lo elimina)
grep "StartLimitIntervalSec" hosts/t14/home/default.nix → debe estar en [Unit]

systemctl --user status waybar                     → active
systemctl --user status monitor-lid-validator      → NOT FOUND
pgrep waybar                                       → PID estable
journalctl --user -u waybar                        → sin crashes
```

---

## CONTEXT FILES (leer en la exploración)

- `openspec/changes/t14-hdm-migration-v2/tasks.md` — 15 tareas HDM
- `openspec/changes/t14-hdm-migration-v2/design.md` — diseño técnico HDM
- `openspec/changes/t14-hdm-migration-v2/specs/` — specs HDM
- `openspec/changes/t14-hdm-migration-v2/PROMPT.md` — prompt original HDM
- `openspec/changes/t14-workspace-switch-resets/exploration.md` — crash de waybar (hallazgos)
- `openspec/changes/t14-workspace-switch-resets/design.md` — diseño del fix de waybar
- `openspec/changes/t14-workspace-switch-resets/CLEANUP-PROMPT.md` — este archivo
- `hosts/t14/home/default.nix` — systemd waybar (con cambios uncommitted)
- `docs/t14-monitor-layout.md` — referencia de monitores

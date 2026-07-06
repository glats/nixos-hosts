# SDD Proposal: revisar-scripts-bin-nix-switch-mact2

## Intent

Revisar, limpiar, y ordenar todos los scripts en `bin/`. El problema principal es que `nixos-build` en mact2 ejecuta `home-manager switch` DESPUES de `darwin-rebuild switch`, cuando nix-darwin ya despliega Home Manager integrado via `darwin/default.nix:11`. Esto es redundante, desperdicia tiempo, y potencialmente causa conflictos. Ademas, hay 8 scripts sin empaquetar en `pkgs/nixos-scripts/` y codigo duplicado entre los scripts WireGuard y en la deteccion de `REPO_ROOT`.

## Scope

### In
- **Fix mact2 HM double invocation**: Remover `home-manager switch` de `switch`, `upgrade`, y `safe` en `nixos-build` cuando corre en Darwin (mact2). La activacion de HM ya ocurre dentro de `darwin-rebuild switch`.
- **Package unpackaged scripts**: Agregar los 8 scripts faltantes a `pkgs/nixos-scripts/default.nix` (sync-opencode-remote, sops-rotate-keys, compare-palette, generate-thinkpad-wireguard, remove-wireguard-peer, add-wireguard-peer, webcam, sops-add-t14).
- **Consolidate WireGuard duplication**: Extraer el preambulo identico (8 lineas) de `add-wireguard-peer`, `remove-wireguard-peer`, y `generate-thinkpad-wireguard` a `bin/lib/common.sh` y sourcearlo.
- **Merge sops-add-t14 into sops-rotate-keys**: Agregar subcomando `add-host <name>` a `sops-rotate-keys` y eliminar `sops-add-t14`.
- **Standardize REPO_ROOT detection**: Usar el patron robusto de `nixos-build` (NIXOS_REPO env var -> git rev-parse -> fallback a HOME) como el patron unico en `bin/lib/common.sh`.

### Out
- No cambiar la estructura de flake.nix, overlays, ni home-linux/shell.nix.
- No refactorizar `compare-palette` ni `webcam` (son herramientas de desarrollo independientes).
- No tocar `sync-opencode-remote` mas alla de empaquetarlo.
- No unificar `add-wireguard-peer` y `remove-wireguard-peer` en un solo script (solo extraer preambulo comun).

## Capabilities

1. **HM-SINGLE-ACTIVATION**: `nixos-build` en Darwin (mact2) activa HM exactamente una vez, via `darwin-rebuild switch` que ya incluye el modulo HM integrado. Los comandos `switch`, `upgrade`, y `safe` en Darwin NO ejecutan `home-manager switch` adicional.
2. **ALL-SCRIPTS-PACKAGED**: Todos los scripts en `bin/` estan empaquetados en `pkgs/nixos-scripts/` y disponibles via `nixos-scripts` derivation en todos los hosts.
3. **SHARED-PREAMBLE**: Los scripts WireGuard (`add-wireguard-peer`, `remove-wireguard-peer`, `generate-thinkpad-wireguard`) comparten preambulo comun via `source bin/lib/common.sh`, eliminando 24 lineas duplicadas.
4. **SINGLE-KEY-TOOL**: `sops-rotate-keys add-host <name>` reemplaza el script `sops-add-t14` de 8 lineas, unificando la funcionalidad de gestion de keys sops en un solo script.

## Approach

**Recommended strategy**: Single change con 4 commits atomicos, ordenados por prioridad e independencia:

1. **Commit 1: Fix mact2 HM bug** (highest priority, lowest risk)
   - `bin/nixos-build`: Remover lineas 131-132 (`switch`), 182-183 (`upgrade`), 301-302 (`safe`) donde `home-manager switch` se ejecuta en Darwin.
   - Verificar: `nix flake check --no-build` pasa.

2. **Commit 2: Create shared library + consolidate**
   - `bin/lib/common.sh`: Nuevo archivo con `REPO_ROOT` detection, `HOST` detection, y helpers (`die()`, `usage()`).
   - WireGuard scripts: Reemplazar preambulo (lineas 1-8 en cada uno) con `source "$(dirname "$0")/lib/common.sh"`.
   - `sops-rotate-keys`: Agregar subcomando `add-host <name>` integrando la logica de `sops-add-t14`.
   - `sops-add-t14`: Eliminar.

3. **Commit 3: Package all 8 scripts**
   - `pkgs/nixos-scripts/default.nix`: Agregar `cp` + `chmod` para los 8 scripts faltantes.
   - La fuente (`src = ../../bin`) ya incluye `lib/common.sh`, pero este NO se instala (es solo para ser sourceado por otros scripts que si se instalan).

4. **Commit 4: Adopt shared lib in remaining scripts** (opcional, bajo riesgo)
   - `nixos-build`, `sops-rotate-keys`, `format-nix`, `code-work`, etc.: Sourcear `lib/common.sh` donde aplique.
   - Actualizar deteccion de `REPO_ROOT` al patron unificado.

## Affected Areas

| File | Impact |
|------|--------|
| `bin/nixos-build` | Remover 6 lineas de HM redundante en Darwin |
| `bin/lib/common.sh` | NUEVO: Biblioteca compartida de shell |
| `bin/add-wireguard-peer` | Reemplazar preambulo con `source` |
| `bin/remove-wireguard-peer` | Reemplazar preambulo con `source` |
| `bin/generate-thinkpad-wireguard` | Reemplazar preambulo con `source` |
| `bin/sops-rotate-keys` | Agregar subcomando `add-host` |
| `bin/sops-add-t14` | ELIMINAR |
| `pkgs/nixos-scripts/default.nix` | Agregar 8 scripts, remover sops-add-t14 (reemplazado) |

**Hosts affected**: mact2 (cambio de comportamiento en activacion), todos (empaquetado), ningun cambio estructural en modulos Nix.

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| mact2 HM config diverge si `darwin-rebuild switch` y `home-manager switch` usaban flake paths diferentes | LOW | Ambos usan `$FLAKE_PATH#$HOSTNAME`. Verificar consistencia antes del cambio. |
| Scripts empaquetados fallan si dependian de `~/.nixos/bin` en PATH | LOW | La derivation ya copia los scripts a `$out/bin`. El PATH via `shell.nix:61` sigue existiendo como fallback. |
| `sops-add-t14` eliminado rompe flujos de otros hosts con nombre diferente | LOW | Generalizar a `add-host <name>` resuelve esto. |
| `lib/common.sh` no se encuentra al sourcear si la estructura de directorios cambia | LOW | Usar path relativo al script (`$(dirname "$0")/lib/common.sh`). |

## Rollback Plan

- **Commit 1**: Revertir las lineas removidas en `nixos-build`. El script soporta revert simplemente restaurando los 3 bloques `if $IS_DARWIN` con `home-manager switch`.
- **Commit 2**: Revertir `bin/lib/common.sh` y restaurar preambulos originales en WireGuard scripts. Restaurar `sops-add-t14` desde git history.
- **Commit 3**: Revertir `pkgs/nixos-scripts/default.nix` al estado previo. Los scripts siguen disponibles via `~/.nixos/bin` en PATH.
- **Commit 4**: Revertir adopcion de `lib/common.sh` en scripts individuales.

Cada commit es independiente y reversible sin afectar a los demas.

## Dependencies

- Ninguna dependencia externa. Todos los cambios son en archivos shell y el derivation Nix.
- `nix flake check --no-build` debe pasar despues de cada commit.

## Success Criteria

1. `nixos-build switch` en mact2 ejecuta `darwin-rebuild switch` y NO ejecuta `home-manager switch` adicional.
2. `nixos-build upgrade` y `nixos-build safe` en mact2 tampoco ejecutan HM adicional.
3. `pkgs/nixos-scripts` contiene todos los scripts de `bin/` (verificar con `ls $out/bin` en nix build).
4. Scripts WireGuard funcionan identico despues de extraer preambulo comun.
5. `sops-rotate-keys add-host t14` hace lo mismo que `sops-add-t14` hacia.
6. `nix flake check --no-build` pasa en todos los hosts.

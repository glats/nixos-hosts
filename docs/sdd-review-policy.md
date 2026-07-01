# SDD Review Policy — Placement Options

Documenta las 8 ubicaciones posibles para `sdd-review-policy.md` y cuál implementamos.

## Cómo OpenCode Resuelve la Configuración

OpenCode mergea (concatena) los arrays `instructions` entre capas de configuración:

```
Global:     instructions: ["SYSTEM_RULES.md"]
Proyecto:   instructions: ["./sdd-review-policy.md"]
Resultado:  instructions: ["SYSTEM_RULES.md", "./sdd-review-policy.md"]
```

Los proyectos **no pueden opt-out** de instrucciones globales. Siempre se concatenan.

---

## Las 8 Ubicaciones Posibles

### 1. `~/.config/opencode/` — Manual

| Aspecto | Detalle |
|---------|---------|
| Mecanismo | Pegar el archivo ahí, agregarlo a `instructions` en `opencode.json` |
| Sobrevive rebuild? | **NO.** El activation script de nix lo pisa |
| Scope | Esta máquina solamente |
| Mantenimiento | Manual, frágil |
| Verdicto | ❌ Descartado — no sobrevive rebuilds |

### 2. `~/.config/opencode/` — Vía Nix (`shared/opencode.nix`)

| Aspecto | Detalle |
|---------|---------|
| Mecanismo | 3 pasos: (a) `home.file` despliega el archivo, (b) activation script convierte symlink → copia, (c) `instructions` en el json lo referencia |
| Sobrevive rebuild? | **SÍ** — los 3 pasos lo garantizan |
| Scope | Todos los hosts (rog, thinkcentre, t14, mact2) |
| Cambios nix | 1 archivo nuevo + 3 líneas en `shared/opencode.nix` |
| Mantenimiento | Editar el archivo en `shared/opencode/`, hacer rebuild |
| Verdicto | ✅ **IMPLEMENTADO** |

### 3. Per-project `.opencode/` (como IFT-3501)

| Aspecto | Detalle |
|---------|---------|
| Mecanismo | Cada proyecto tiene su `.opencode/sdd-review-policy.md` y su `opencode.json` lo referencia |
| Sobrevive rebuild? | No aplica — fuera de nix |
| Scope | Solo el proyecto que lo tiene |
| Mantenimiento | Multiplicado por N proyectos. Actualizar la policy requiere tocar todas las copias |
| Verdicto | ❌ Descartado — no escala, difícil de mantener consistente |

### 4. Embebido en `AGENTS.md`

| Aspecto | Detalle |
|---------|---------|
| Mecanismo | Agregar el policy como una sección más de AGENTS.md |
| Sobrevive rebuild? | AGENTS.md viene de `gentle-ai-assets` — capa 2, "NO TOCAR" |
| Riesgo | Modificar AGENTS.md = tocar Gentle AI framework |
| Verdicto | ❌ Descartado — viola la restricción de no tocar skills |

### 5. Embebido en el orchestrator (`sdd-orchestrator.md`)

| Aspecto | Detalle |
|---------|---------|
| Mecanismo | El iteration protocol vive dentro del skill del orquestador |
| Sobrevive rebuild? | `sdd-orchestrator.md` viene de `gentle-ai-assets` — capa 2 |
| Riesgo | Viola la restricción del usuario |
| Verdicto | ❌ Descartado — toca Gentle AI framework |

### 6. Como plugin o MCP server

| Aspecto | Detalle |
|---------|---------|
| Mecanismo | Un MCP server que trackea review checkpoints y fuerza gates |
| Complejidad | Overkill para un policy de ~120 líneas de texto |
| Mantenimiento | Código a mantener, deploy separado |
| Verdicto | ❌ Descartado — complejidad innecesaria |

### 7. Embebido en el schema/convención SDD

| Aspecto | Detalle |
|---------|---------|
| Mecanismo | El iteration protocol vive en `sdd-phase-common.md` o `sdd-status-contract.md` |
| Ubicación | `skills/_shared/` → Gentle AI framework, capa 2 |
| Riesgo | Viola la restricción del usuario |
| Verdicto | ❌ Descartado — toca Gentle AI framework |

### 8. Como opción de módulo Nix (`home.opencode.extraInstructions`)

| Aspecto | Detalle |
|---------|---------|
| Mecanismo | Agregar una opción nueva al módulo `home.opencode` que acepte instrucciones extra |
| Existe hoy? | No. `home.opencode` tiene `agents`, `permissions`, `plugins` — no `extraInstructions` |
| Scope | Por host, configurable |
| Esfuerzo | Crear la opción en el módulo + usarla en `shared/opencode.nix` |
| Verdicto | ❌ Descartado — más complejo que la opción 2 sin beneficio adicional |

---

## Qué Implementamos: Opción 2 — Global vía Nix

### Archivo

```
shared/opencode/sdd-review-policy.md  →  desplegado a ~/.config/opencode/
```

### Cambios en `shared/opencode.nix`

| Línea | Cambio |
|-------|--------|
| 72 | `instructions = [ "SYSTEM_RULES.md" "sdd-review-policy.md" ]` |
| ~93 | Nuevo bloque `home.file` para desplegar el archivo |
| ~147 | Agregar al `for file in ...` del activation script |

### La Policy

- **Binary iteration gate**: solo 2 opciones — `full-iteration` (re-explore → re-apply) o `proceed`
- **Sin inline-fixes**: si el apply falló, el approach necesita reexaminarse
- **Re-explore informado**: lee todos los artifacts previos + review feedback como contexto
- **Artifact lifecycle**: upsert vía topic_key (Engram) + file overwrite (OpenSpec)
- **Proceed escape hatch**: el usuario siempre puede saltar cualquier gate
- **No toca skills**: policy como instruction text, no modifica Gentle AI

### Workflow

```
explore → propose → spec → design → tasks → apply  [AUTOMÁTICO]
                                                │
                                      review-checkpoint
                                                │
                            ┌───────────────────┼───────────────────┐
                            ▼                   ▼                   ▼
                        approved          changes-requested    blocked/pending
                            │                   │                   │
                        verify          ⚡ ASK USER:           STOP
                                        full-iteration?
                                            │
                              ┌─────────────┴─────────────┐
                              ▼                           ▼
                        full-iteration                proceed
                        (re-explore →                  (skip gate)
                         → re-apply)
```

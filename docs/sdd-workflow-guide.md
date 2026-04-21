# Guía Rápida: SDD Workflow con Gentle-AI

## ¿Qué es SDD?

**Spec-Driven Development** = Desarrollo guiado por especificaciones.

En lugar de "hacé esto", usás fases estructuradas:
```
Explorar → Proponer → Especificar → Diseñar → Dividir → Aplicar → Verificar → Archivar
```

## Conceptos Clave

| Concepto | Descripción | ¿Cuándo usar? |
|----------|-------------|---------------|
| **Orchestrator** | Coordina, NO ejecuta | Siempre activo por defecto |
| **Sub-agentes** | Ejecutan el trabajo real | Llamados por el orchestrator |
| **delegate()** | Delega trabajo async | Para tareas grandes (4+ archivos) |
| **task()** | Delega trabajo sync | Cuando necesitás el resultado antes de continuar |
| **Skills** | Instrucciones específicas para cada fase | Cargados automáticamente por sub-agentes |

## ¿Cuándo usar SDD?

### ✅ Usar SDD cuando:
- Cambios afectan **4+ archivos**
- Necesitás **planificar antes de codear**
- Querés **documentar** el proceso
- Es un **feature complejo** que requiere análisis
- Querés **persistir** en engram para referencia futura

### ❌ NO usar SDD cuando:
- Cambios simples (1-3 archivos)
- Fix rápido de typo
- Consulta puntual
- Tareas exploratorias sin implementación

## Comandos Principales

### `/sdd-onboard`
**Propósito**: Iniciar un ciclo SDD completo de forma guiada.

**Uso**:
```
/sdd-onboard
→ "Quiero auditar la integración de gentle-ai en mi NixOS"
```

**Qué hace**:
1. Ejecuta `sdd-init` (bootstrap)
2. Ejecuta `sdd-explore` (investiga)
3. Ejecuta `sdd-verify` (valida)
4. Genera resumen en engram

### `/sdd-explore`
**Propósito**: Investigar el codebase sin escribir código.

**Uso**:
```
/sdd-explore "Explora el módulo de networking de mi NixOS"
```

**Qué hace**:
- Lee archivos relevantes
- Analiza estructura
- Reporta hallazgos
- NO modifica archivos

### `/sdd-propose`
**Propósito**: Crear propuesta de cambio.

**Uso**:
```
/sdd-propose "Propón cómo mejorar la estructura de servicios"
```

**Qué hace**:
- Define el scope del cambio
- Explica el approach
- Crea archivo de propuesta

### `/sdd-spec`
**Propósito**: Escribir especificaciones detalladas.

**Uso**:
```
/sdd-spec "Especifica los requisitos para el nuevo servicio"
```

**Qué hace**:
- Define requisitos
- Crea escenarios/criterios de aceptación
- Documenta en engram

### `/sdd-tasks`
**Propósito**: Dividir la especificación en tareas.

**Uso**:
```
/sdd-tasks "Divide la especificación del servicio en tareas implementables"
```

### `/sdd-apply`
**Propósito**: Implementar el código.

**Uso**:
```
/sdd-apply "Implementa el servicio según las tareas definidas"
```

### `/sdd-verify`
**Propósito**: Validar que la implementación cumple la spec.

**Uso**:
```
/sdd-verify "Verifica que el servicio cumple los requisitos"
```

## Ejemplos Prácticos

### Ejemplo 1: Auditoría (lo que intentaste)

**❌ Forma incorrecta** (hace todo inline):
```
"Revisa si gentle-ai está bien configurado con mi nixos"
→ Lee archivos inline, no delega
```

**✅ Forma correcta** (usa SDD workflow):
```
/sdd-onboard
→ "Auditar integración de gentle-ai en mi NixOS"

# O paso a paso:
/sdd-explore "Investiga la configuración actual de gentle-ai"
/sdd-verify "Verifica contra upstream de GitHub"
/sdd-propose "Propón mejoras si hay gaps"
```

### Ejemplo 2: Feature complejo

**❌ Forma incorrecta**:
```
"Agregá soporte para PostgreSQL a todos los hosts"
→ Hace todo inline, puede fallar
```

**✅ Forma correcta**:
```
/sdd-explore "Explora cómo está estructurado el soporte de bases de datos"
/sdd-propose "Propón cómo agregar PostgreSQL"
/sdd-spec "Especifica los requisitos del servicio PostgreSQL"
/sdd-design "Diseña la integración con NixOS"
/sdd-tasks "Divide en tareas: módulo, secrets, config"
/sdd-apply "Implementa el módulo PostgreSQL"
/sdd-verify "Verifica que funciona en ambos hosts"
```

## Flujo Normal vs SDD

### Flujo Normal (Chat)
```
Vos: "Agregá nginx"
IA: (hace todo inline)
   - Lee archivos
   - Escribe config
   - Aplica cambios
```

### Flujo SDW
```
Vos: "/sdd-onboard - Quiero agregar nginx"
Orchestrator: "Voy a delegar esto..."
   → sdd-explore: "Investiga cómo agregar nginx"
   → sdd-propose: "Crea propuesta"
   → sdd-spec: "Especifica requisitos"
   → sdd-design: "Diseña integración"
   → sdd-tasks: "Divide en tareas"
   → sdd-apply: "Implementa cambios"
   → sdd-verify: "Valida funcionamiento"
   → sdd-archive: "Guarda documentación"
```

## Tips Importantes

### 1. El Orchestrator decide
No tenés que decir "delegá". El orchestrator decide automáticamente basado en:
- **4+ archivos** → Delega
- **Complejidad** → Delega
- **Simple** (1-3 archivos) → Hace inline

### 2. Usá comandos `/sdd-*`
Los comandos específicos activan el sub-agente correspondiente:
- `/sdd-explore` → Usa agente sdd-explore
- `/sdd-apply` → Usa agente sdd-apply
- etc.

### 3. Engram guarda todo
Las fases SDD guardan automáticamente en engram:
- Exploraciones
- Propuestas
- Especificaciones
- Verificaciones

Consultá con:
```
/engram_search "sdd explore nginx"
```

### 4. Si no delega
Si el orchestrator hace todo inline cuando no debería:

**Posibles causas**:
- El prompt del orchestrator no está cargado
- Las herramientas `delegate`/`task` no están disponibles
- El modelo no sigue instrucciones (probar con Claude)

**Solución**:
```
# Verificar configuración
cat ~/.config/opencode/opencode.json | grep -A 5 "sdd-orchestrator"

# Si todo está bien, usar comandos explícitos:
/sdd-explore "..."
```

## Troubleshooting

### "No hace delegate"
1. Verificar que el agente sea `sdd-orchestrator`
2. Verificar que tenga tools: `delegate`, `task`, `delegation_list`, `delegation_read`
3. Verificar que el prompt simplificado esté cargado
4. Si usa Kimi/Qwen y no funciona, probar con Claude

### "Los sub-agentes no ejecutan"
1. Verificar que existan los skills en `~/.config/opencode/skills/sdd-*/`
2. Verificar que el modelo del sub-agente tenga acceso a tools (bash, read, edit, write)

### "No guarda en engram"
1. Verificar que engram MCP esté configurado:
   ```
   cat ~/.config/opencode/opencode.json | grep -A 5 '"engram"'
   ```
2. Verificar que el paquete `engram` esté instalado

## Configuración Actual

Ver tu configuración:
```bash
# Modelos asignados
cat ~/.config/opencode/opencode.json | jq '.agent | to_entries[] | select(.key | startswith("sdd")) | {name: .key, model: .value.model}'

# Herramientas disponibles
cat ~/.config/opencode/opencode.json | jq '.agent.sdd-orchestrator.tools'

# Assets instalados
ls -la ~/.config/opencode/
```

## Recursos

- **Upstream**: https://github.com/Gentleman-Programming/gentle-ai
- **Skills**: `~/.config/opencode/skills/`
- **Engram**: `engram search "sdd"`
- **Issues**: https://github.com/Gentleman-Programming/agent-teams-lite/issues

---

**Recordatorio**: SDD es para cambios **sustanciales**. Para tareas simples, usá el chat normal.

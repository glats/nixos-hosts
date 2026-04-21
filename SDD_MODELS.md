# SDD Model Assignments - DeepInfra

> Cost-optimized configuration for Gentle-AI / OpenCode SDD workflow

## Modelos por Fase

| Fase | Modelo | Costo In/Out | Por qué |
|------|--------|--------------|---------|
| **sdd-orchestrator** | `deepseek-ai/DeepSeek-V3` | $0.32/$0.89 | Balance perfecto: sigue instrucciones, razona bien, barato. Mejor que Kimi para agentes. |
| **sdd-explore** | `Qwen/Qwen3.6-35B-A3B` | $0.09/$0.60 | Ultra barato. Exploración = lectura de código, no necesita modelo caro. |
| **sdd-propose** | `deepseek-ai/DeepSeek-V3` | $0.32/$0.89 | Decisiones arquitectónicas necesitan razonamiento. DeepSeek mejor que Qwen para esto. |
| **sdd-spec** | `Qwen/Qwen3.6-35B-A3B` | $0.09/$0.60 | Escritura estructurada = trabajo mecánico. Qwen lo hace bien y barato. |
| **sdd-design** | `deepseek-ai/DeepSeek-V3` | $0.32/$0.89 | Diseño técnico = decisiones importantes. DeepSeek para calidad. |
| **sdd-tasks** | `Qwen/Qwen3.6-35B-A3B` | $0.09/$0.60 | Desglose mecánico = tarea simple. Qwen suficiente. |
| **sdd-apply** | `Qwen/Qwen3-Coder-480B-A35B-Instruct-Turbo` | $0.22/$1.00 | **Especializado**: "most agentic code model". Diseñado específicamente para implementación. |
| **sdd-verify** | `Qwen/Qwen3.6-35B-A3B` | $0.09/$0.60 | Validación = comparar contra spec. No requiere modelo premium. |
| **sdd-init** | `Qwen/Qwen3.5-35B-A3B` | $0.09/$0.60 | Bootstrap = tarea simple y única. El más barato. |
| **sdd-archive** | `Qwen/Qwen3.5-35B-A3B` | $0.09/$0.60 | Archive = copiar y cerrar. Mínimo costo. |
| **sdd-onboard** | `Qwen/Qwen3.6-35B-A3B` | $0.09/$0.60 | Onboarding = exploración guiada. Qwen suficiente. |
| **neutral** | `deepseek-ai/DeepSeek-V3` | $0.32/$0.89 | Chat diario + capacidad de delegar si es necesario. |

## Costo Estimado por Ciclo SDD Completo

```
Escenario: Feature mediana (explore → propose → spec → design → tasks → apply → verify → archive)

Fases con DeepSeek (orchestrator, propose, design): 3 × $0.60 avg = $1.80
Fases con Qwen 3.6 (explore, spec, tasks, verify, onboard): 5 × $0.35 avg = $1.75
Fases con Qwen Coder (apply): 1 × $0.60 avg = $0.60
Fases con Qwen 3.5 (init, archive): 2 × $0.35 avg = $0.70

TOTAL: ~$4.85 por ciclo SDD completo
```

Comparación:
- **Toda Kimi**: ~$15-20 (3-4x más caro)
- **Toda Claude**: ~$30-50 (6-10x más caro)
- **Toda Qwen 3.5**: ~$3 (más barato pero orchestrator débil)

## Cuándo Usar Modelo Premium

**Para casos complejos**, cambiar manualmente:

```json
// Para feature crítica o rediseño arquitectónico:
"sdd-propose": { "model": "anthropic/claude-4-sonnet" }
"sdd-design": { "model": "anthropic/claude-4-sonnet" }
```

**Claude 4 Sonnet** ($3-6 per 1M tokens):
- Usar cuando: nuevo sistema, microservicios, cambios breaking, decisiones de arquitectura que duran años
- No usar para: bug fixes, refactors simples, añadir campos a formularios

**GLM-5.1** ($1.4/$4.4):
- Alternativa media entre DeepSeek y Claude
- "Agentic engineering" nativo
- Costo alto pero bueno para código complejo

## Configuración JSON

```json
{
  "agent": {
    "neutral": {
      "model": "deepinfra/deepseek-ai/DeepSeek-V3"
    },
    "sdd-orchestrator": {
      "model": "deepinfra/deepseek-ai/DeepSeek-V3"
    },
    "sdd-init": {
      "model": "deepinfra/Qwen/Qwen3.5-35B-A3B"
    },
    "sdd-explore": {
      "model": "deepinfra/Qwen/Qwen3.6-35B-A3B"
    },
    "sdd-propose": {
      "model": "deepinfra/deepseek-ai/DeepSeek-V3"
    },
    "sdd-spec": {
      "model": "deepinfra/Qwen/Qwen3.6-35B-A3B"
    },
    "sdd-design": {
      "model": "deepinfra/deepseek-ai/DeepSeek-V3"
    },
    "sdd-tasks": {
      "model": "deepinfra/Qwen/Qwen3.6-35B-A3B"
    },
    "sdd-apply": {
      "model": "deepinfra/Qwen/Qwen3-Coder-480B-A35B-Instruct-Turbo"
    },
    "sdd-verify": {
      "model": "deepinfra/Qwen/Qwen3.6-35B-A3B"
    },
    "sdd-archive": {
      "model": "deepinfra/Qwen/Qwen3.5-35B-A3B"
    },
    "sdd-onboard": {
      "model": "deepinfra/Qwen/Qwen3.6-35B-A3B"
    }
  }
}
```

## Justificación por Modelo

### DeepSeek-V3 (orchestrator, propose, design)
- ✅ Sigue instrucciones de system prompt
- ✅ Buen razonamiento para decisiones
- ✅ 10x más barato que Claude
- ✅ Contexto 163K tokens (suficiente)
- ❌ No tan capaz como Claude para lo más complejo

### Qwen3-Coder-480B (apply)
- ✅ Diseñado específicamente para coding agentic
- ✅ "Comparable to Claude Sonnet" según Qwen
- ✅ Especializado en tareas de implementación
- ⚠️ Más caro que Qwen 3.6 pero vale la pena para code

### Qwen3.6-35B (explore, spec, tasks, verify, onboard)
- ✅ Ultra barato ($0.09/$0.60)
- ✅ Contexto 262K tokens (grandísimo)
- ✅ Suficiente para tareas mecánicas
- ✅ Buen balance calidad/precio

### Qwen3.5-35B (init, archive)
- ✅ El más barato
- ✅ Tareas simples: bootstrap y cleanup
- ✅ Contexto suficiente

## Modelos a EVITAR

| Modelo | Problema |
|--------|----------|
| `moonshotai/Kimi-K2.5` | No delega, ignora system prompts, hace todo inline |
| `zai-org/GLM-5` | No entiende concepto de agentes |
| `zai-org/GLM-5.1` | Bueno pero muy caro ($1.4/$4.4) |
| Modelos < 7B | Demasiado pequeños para SDD |

## Comandos Útiles

```bash
# Ver costo actual
# DeepSeek-V3: ~$0.60 por 1K tokens de interacción
# Qwen3.6: ~$0.35 por 1K tokens
# Qwen3.5: ~$0.35 por 1K tokens

# Para feature simple (pocas fases):
# Total: ~$2-3

# Para feature compleja (todas las fases):
# Total: ~$5-8

# Si usaras Claude para todo:
# Total: ~$25-40
```

## Actualización de Configuración

Para aplicar esta configuración:

1. Copiar el bloque JSON de arriba
2. Pegar en `modules/home/opencode/opencode.json.base`
3. Ejecutar `nixos-build switch`
4. Reiniciar OpenCode

## Notas

- Precios en USD per 1M tokens
- Cache read = 10x más barato (aprovechar con system prompts largos)
- DeepSeek-V3 = mejor opción orquestador en DeepInfra
- Qwen Coder = mejor opción para implementación específica
- Evitar Kimi para SDD (no funciona como agente)

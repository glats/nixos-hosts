# opencode Session Recovery

## Symptoms
- `opencode session list` no muestra sesiones recientes de este proyecto
- `/sessions` solo muestra algunas sesiones, faltan las de hoy
- Las sesiones existen en la SQLite pero no aparecen en el listado

## Cause
Las sesiones se crearon con un `project_id` específico del proyecto (hash del directorio), pero `opencode session list` filtra por el proyecto actual. Si el contexto cambió (ej: al ejecutar `nix-switch` u otros comandos en otro directorio), las sesiones quedan adoptadas bajo un `project_id` distinto y se vuelven invisibles.

## Recovery

```sql
-- 1. Identificar el project_id problemático
sqlite3 ~/.local/share/opencode/opencode.db \
  "SELECT DISTINCT project_id FROM session WHERE project_id != 'global' AND project_id != '<known-project-id>';"
-- 2. Buscar sesiones de ese project_id
sqlite3 ~/.local/share/opencode/opencode.db \
  "SELECT id, title FROM session WHERE project_id = '<problematic-hash>';"
-- 3. Reasignar a global para que aparezcan en el listado
sqlite3 ~/.local/share/opencode/opencode.db \
  "UPDATE session SET project_id = 'global' WHERE project_id = '<problematic-hash>';"
-- 4. Verificar
sqlite3 ~/.local/share/opencode/opencode.db \
  "SELECT COUNT(*) FROM session WHERE project_id = '<problematic-hash>';"  -- debe devolver 0
```

## Prevention
- Antes de ejecutar comandos de otro proyecto (`nix-switch`, etc.), considerar abrir una terminal aparte
- Si vuelve a pasar, las conversaciones **nunca se pierden** — solo el filtro las oculta. Están intactas en la SQLite.

## Data Location
- DB: `~/.local/share/opencode/opencode.db`
- Tablas: `session`, `message`, `part`
- Mensajes totales: contabilizados vía `SELECT COUNT(*) FROM message JOIN session ON message.session_id = session.id WHERE session.project_id = 'global';`

# OpenCode V2 Final Cutover

OpenCode V2 remains opt-in as `opencode2` until the SDD and reviewer round-trip
has passed on `rog`, `thinkcentre`, `t14`, and `macm5`. Do not run this migration
until that gate is recorded and the V1 fallback is no longer needed.

## Preconditions

- The V2 configuration, seven MCP servers, and five native adapters have passed
  their host matrix validation.
- Export a backup of both isolated roots. Preserve ownership and file modes.
- Stop the V2 native background service before moving its database and session
  files.

## Migration

On either platform, stop the isolated V2 service with `opencode2 service stop`.

Move the V2 configuration into the default XDG configuration root, then move
the complete V2 data root into the default XDG data root. The configuration move
preserves `opencode.json`, `AGENTS.md`, native skills, commands, plugins, and
`cli.json`. The data move preserves sessions, the OpenCode database, cached
state, and stored credentials. Do not merge only selected files: session and
credential formats are version-owned and must travel with their data root.

Update the Home Manager options so the V2 runtime uses the default XDG roots,
activate the new generation, then start the native service with `opencode2`.
Confirm the service is
healthy, the prior sessions are listed, a provider can authenticate using the
preserved credentials, and all seven MCPs reconnect.

## Rollback

Stop the default-root V2 native service, restore the backed-up default roots, and
put the saved V2 roots back at `~/.config/opencode-v2` and `~/.local/opencode-v2`.
Re-activate the previous generation. V1 remains a separate fallback throughout
the migration and is not modified by this procedure.

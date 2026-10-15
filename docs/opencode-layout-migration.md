# OpenCode layout migration

Home Manager migrates the previous versioned OpenCode data into the native XDG
layout during activation. It preserves the database, sessions, credentials,
history, state, and user configuration, while archiving pre-existing native-path
content and other legacy files rather than overwriting or deleting them.

## Before activation

Stop the old server first. Read its PID from `service.json` under the previous
versioned runtime root and run `kill <pid>`. Activation refuses to migrate while
that process is alive; rerun activation after it has stopped.

The archive is stored at
`~/.local/share/opencode-migration-archive/<UTC timestamp>/`. Migrated prior
native-path contents are under `previous/`; remaining legacy files are under
`old/`. If activation is interrupted, rerunning it resumes the in-progress
archive.

## Verify

Check the effective paths and confirm sessions and authentication:

```sh
opencode debug paths
opencode session list
opencode auth list
```

`auth list` is optional and may not be available in every CLI build; `opencode
--help` lists the supported commands. Confirm expected sessions are present and
providers can authenticate before removing the archive.

## Rollback

Revert to the previous Home Manager generation. With OpenCode stopped, move the
archived `previous/` and `old/` items back to their original locations, preserving
the archive until the restored layout is verified. Do not overwrite newer files;
resolve any path collisions before restoring. Once satisfied with the migration,
the user may delete the archive.

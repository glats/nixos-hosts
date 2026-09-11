# Tasks: rtk-init-helper

## Phase 1 — Managed RTK contract

- [x] 1.1 Create the delta specification and task register.
- [x] 1.2 Implement `internal/rtkinit` block management, atomic writes, and table-driven tests.
- [x] 1.3 Implement the thin `cmd/rtk-init` CLI and default path resolution.
- [x] 1.4 Wire `cmd/rtk-init` into `pkgs/nixos-scripts/default.nix`.
- [x] 1.5 Migrate `AGENTS.md` to exactly one managed RTK block and verify idempotency.
- [x] 1.6 Run Go, formatting, flake, and derivation evaluation gates; commit and push.

## Work Unit Evidence

| Evidence | Result |
|---|---|
| Focused test command and exact result | `go -C pkgs/nixos-scripts test ./...` — passed, 307 tests in 33 packages |
| Runtime harness command/scenario and exact result | `go -C pkgs/nixos-scripts run ./cmd/rtk-init` — already up to date; `--check` twice — both `ok` |
| Rollback boundary | Revert this change's artifacts, Go package/CLI, derivation line, and managed AGENTS.md block |

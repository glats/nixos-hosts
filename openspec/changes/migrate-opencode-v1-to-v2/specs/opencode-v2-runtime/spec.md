# opencode-v2-runtime Specification

## Purpose

Isolated V2 runtime: pinned binary, directory isolation, supervised shared server, project-config gating, clean auth.

## Requirements

### Requirement: Pinned V2 platform tarball

`pkgs/opencode-v2` MUST fetch a hash-pinned `@opencode/cli-<os>-<arch>@2.0.14` tarball, wrapped with `autoPatchelfHook` + `makeBinaryWrapper` into one `opencode2` binary, with no postinstall or npm/node/bun.

#### Scenario: Reproducible build [rog, thinkcentre, t14, macm5]

- GIVEN the V2 derivation
- WHEN it builds on linux and darwin
- THEN `opencode2 --version` prints `2.0.14`
- AND `opencode --version` prints V1 `1.18.32`

### Requirement: V1 fallback preserved at current version

Introducing V2 MUST NOT alter the installed V1 package, version, or behavior: `pkgs/opencode` SHALL remain pinned at its current `1.18.32`, and `opencode` MUST continue to resolve to that V1 binary. The migration MUST NOT downgrade V1 to `1.18.22`.

#### Scenario: V1 unchanged while V2 is introduced [rog, thinkcentre, t14, macm5]

- GIVEN V1 is installed at `1.18.32`
- WHEN the V2 package and wrapper are delivered
- THEN `opencode --version` still prints `1.18.32`
- AND the V1 `opencode` behavior, config, and data paths are unchanged

### Requirement: Version-scoped directory isolation

The `opencode2` wrapper MUST set all XDG base dirs plus `OPENCODE_CONFIG_DIR`, `OPENCODE_DB`, and `TMPDIR`, rooted in the V2 dir with no V1 fallback, via one Home Manager function.

#### Scenario: Same-folder coexistence [rog, thinkcentre, t14, macm5]

- GIVEN V1 and V2 launched in one repo
- WHEN both run concurrently
- THEN each uses only its own dirs

#### Scenario: Fresh launch writes nothing under V1 [rog, t14]

- GIVEN an empty V2 dir
- WHEN `opencode2` launches
- THEN no file appears under `~/.config/opencode` or `~/.local/share/opencode`
- AND its credential store is empty with V1 `auth.json` unmodified

### Requirement: Supervised service lifecycle

The `opencode2` wrapper MUST NOT append `--standalone`; V2 SHALL run its native shared server under the V2 state root. On Linux hosts (rog, thinkcentre, t14) the server SHALL run as a supervised systemd user service; on macm5 it SHALL run as a launchd agent. Both SHALL launch with the same central `mkV2Environment` exports as the interactive wrapper. Activation SHALL restart the supervised service ONLY when the generated V2 `opencode.json` changes.

#### Scenario: Config regen restarts server [rog, macm5]

- GIVEN the supervised V2 service running
- WHEN activation regenerates a changed `opencode.json`
- THEN activation restarts the service with the wrapper env
- AND unchanged config triggers no restart

#### Scenario: Platform-supervised service [rog, thinkcentre, t14, macm5]

- GIVEN V2 delivered on a Linux host
- WHEN the user session starts
- THEN a systemd user service runs `opencode2` under the V2 state root
- AND on macm5 a launchd agent does the same with the same V2 env

#### Scenario: Post-switch discovery [rog, macm5]

- GIVEN V2 switched in as the active runtime
- WHEN the user inspects the running service
- THEN `systemctl --user status opencode2` (Linux) or `launchctl list` (macm5) shows the V2 server under the V2 state root
- AND V1 paths and process are unaffected

#### Scenario: Recovery after failure [rog, macm5]

- GIVEN the supervised V2 service stopped or crashed
- WHEN activation runs or the service is restarted
- THEN it restarts with the V2 env
- AND recovery never falls back to V1 nor writes under V1 dirs

### Requirement: Project config disabled by default

The default `opencode2` wrapper MUST set `OPENCODE_DISABLE_PROJECT_CONFIG=1`. An opt-in wrapper MAY enable project config and MUST refuse a repo whose `.opencode/package.json` pins the V1 SDK.

#### Scenario: Project config gated by opt-in [t14]

- GIVEN a V1-SDK `.opencode/package.json`
- WHEN the default `opencode2` loads
- THEN it reads no project `opencode.json` or `AGENTS.md`
- AND the opt-in wrapper refuses the repo as not V2-compatible

### Requirement: Clean auth with optional one-way seed

A fresh V2 launch MUST start with an empty credential store and MUST NOT import V1 `auth.json`; an optional seed command MAY copy it (read-only) into the V2 dir.

#### Scenario: Seed is one-way [rog]

- GIVEN the opt-in seed command
- WHEN it copies V1 `auth.json`
- THEN V1 `auth.json` is unchanged and V2 imports the proxy credential

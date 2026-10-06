# Design: Retire OpenCode V1

## Technical Approach

Implement proposal #3626/five delta specs #3628 under matching hybrid revision 1 (#3624). Retire active V1 on rog/thinkcentre/t14/macm5; preserve archival data, dirty migrations, credential-collision work, Gentle AI 2.5.0 and CLI/SDK 2.0.14. No namespace cutover, research phase, upgrades, activation or commits.

## Architecture Decisions

| Option | Tradeoff | Decision/rationale |
|---|---|---|
| Delete shared modules / trim emission | V2 consumes cfg.agents/cfg.permissions/upstream overlay | Trim V1 only; retain shared dependencies |
| New manifest/executables / existing Go helper | opencode-home already accepts absolute OPENCODE_HOME_BINARY, inherited environment and syscall.Exec | Reuse; no launcher.json, new binaries or profile replacement |
| Credential importer / refuse legacy seed | Optional bootstrap does not justify credential migration | Refuse before writes; native sign-in remains supported |
| Namespace rename / retain identity | Rename changes server/session ownership | Preserve native store executable, environment and names; no bare opencode alias |

## Data Flow

HM environment → existing shell launchers → native V2 executable. opencode2-home supplies OPENCODE_HOME_BINARY → Go opencode-home → syscall.Exec. Keep standalone/server argument placement unchanged. Noninteractive consumers source the environment and supply the native absolute target; no shell-alias dependency. Go default resolves opencode2, never opencode; validate consistent isolated XDG/OPENCODE environment, reject missing/nonexecutable/resolved-self targets before probing/spawning. Missing isolation fails, not default-namespace startup. Preserve custom runtimeRoot and PID/server identity.

Home helper scrubs inherited proxy variables; listener up sets child HTTP(S)_PROXY and loopback exclusions, down prints notice and launches clean. Profiles/ordinary launchers/daemon acquire no proxy exports; local MCP scrubbing stays intact.

V2 setup activation → completed V2 skills → OpenFang existing cmp-copy/orphan cleanup, ordered after setup. Remote sync uses V2 directories; preflight existing remote isolated runtime/environment before backup/transfer, reject unavailable/unsupported targets without writes. Transfer managed assets only, excluding credentials/databases; retain destination-specific environment. Remove V1 npm provisioning/provider rewriting/plugin stripping; no new remote provisioning workflow.

## File Changes

Braces enumerate files; no additions.

| File | Action | Purpose |
|---|---|---|
| pkgs/opencode/default.nix; pkgs/opencode-npm-packages/{default.nix,versions.json,node-modules.json} | Delete | V1 derivations |
| lib/packages.nix; overlays/{linux,darwin}.nix | Modify | Remove V1 exports |
| linux/system/base/profiles/dev.nix; darwin/home/packages.nix | Modify | Remove V1 consumption; retain V2 package |
| shared/opencode.nix; shared/opencode/runtime-config.nix | Modify | Remove V1 emission/options/activation; retain shared gates; retarget OpenFang |
| shared/opencode-profile.nix; shared/shell-aliases.nix | Modify | Remove V1 assignments/stale comments; preserve launch functions |
| shared/opencode/{plugins.nix,rtk.ts} | Delete | V1-exclusive wiring |
| shared/opencode/providers-base.nix | Modify | Trim V1 exports, not routing/allowlist |
| pkgs/gentle-ai-assets/default.nix; pkgs/engram-assets/{default.nix,vanilla.nix} | Modify | Stop V1 plugin emission; retain overlay/commands/V2 |
| pkgs/nixos-scripts/internal/opencodehome/{launcher.go,launcher_test.go} | Modify | Isolated default, target guards/proxy hygiene |
| pkgs/nixos-scripts/cmd/{install-opencode-auth-seed,sync-opencode-remote}/{main.go,main_test.go} | Modify | Legacy-seed refusal/V2 remote defaults and regressions |
| shared/opencode/home-launcher.test.py; docs/{home-link.md,opencode-v2-final-cutover.md} | Modify | V2 assertions/current instructions; preserve overlapping edits |

Retain agents.nix, permissions.nix, v2 adapters, MCP modules, providers.nix, nixos-scripts registration, native V2 derivation and flake.lock.

## Interfaces / Auth Limitation

Retain home.opencode.enable shared packages/API-key exports, extraInitContent, activeProviderName, disabledTools, agents, permissions and all v2 options/defaults. Remove compaction/plugins/tuiPlugins/activePlugins with callers; document removal of external assignments (unknown-option errors). Preserve BrowserMCP/no-restart activation.

Context7 storage docs and isolated pinned 2.0.14 auth/login --help establish SQLite storage and login/list/logout/switch, not seed import. Help exposes target/--method/--standalone/--server. Refuse every legacy-seed invocation, including --v2, before fetch/decrypt/backup/write; nonzero exit, no credential reads, overwrite, DB edit or false success. Recommend verified opencode2-home auth login openai on macm5; select native OAuth interactively. Credentials/backups remain untouched. MAY bootstrap permits disabling optional fallback; proposal permits retiring helpers. No importer blocks retirement.

## Threat Matrix / RED Tests

Applicable rows propagate to tasks.

| Boundary | Applicability | Safe/failure behavior; RED target |
|---|---|---|
| Documentation-like paths | N/A | No executable classifier |
| Git repository selection | N/A | No Git selector changes |
| Commit state | N/A | No index/commit changes |
| Push state | N/A | No push routing |
| PR commands | N/A | No PR automation |
| Process routing | Applicable | Missing isolation/native, recursive target: no spawn/write; opencodehome/launcher_test.go |
| Arguments/proxy | Applicable | Empty/spaced argv, standalone/server, inherited proxy/listener up/down: exact arguments/clean failure; launcher_test.go, home-launcher.test.py |
| Remote paths/auth | Applicable | Quoted/injected paths, unavailable V2: reject before writes; default/--v2/invalid/API-key/conflict seed: actionable nonzero refusal before fetch/decrypt/auth-access/backup/write, no success claim; assert zero calls, unchanged credentials/backups; helper main_test.go |
| Activation | Applicable | V1 fixture unchanged, V2 config/skills/OpenFang order preserved; home-launcher.test.py |

## Rollout / Open Questions

Snapshot dirty ownership/generations; RED tests, edits/formatting, Go suite/Python regression, nix flake check --no-build. Separately evaluate three Linux toplevel drvPaths, macm5 Darwin toplevel and four standalone-HM activationPackage drvPaths. Later authorized rollout: rog first, reachable hosts next; isolated PONG/OAuth-refresh/MCP proof. Unavailable remote = UNVERIFIED. Rollback retirement-only changes/old generations; no secrets decryption, credential copying or GC.

Resolved: #3628/filesystem Auth-Seed Fallback Safety permits refusal without backups/importer. Backup-before-mutation applies only to supported bootstrap. No open questions/blockers; ready for tasks.

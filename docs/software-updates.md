# Update, validate, then activate

`nix-upgrade` changes source versions, hashes and locks only. `nix-switch` builds and activates the selected configuration without updating its sources. Both aliases still delegate to `nixos-build`; no per-language commands are required.

## Workflow

From the selected repository worktree:

```console
nix-upgrade
git diff -- flake.lock pkgs/opencode pkgs/opencode-npm-packages-v2 pkgs/browsermcp-v2
nixos-build check
nix-switch
```

Run the last command only when ready to activate. `nixos-build build` builds without activation. Existing `boot`, `test`, `dry`, and `safe` retain their behavior; `safe` includes activation.

Upgrade runs, in order:

1. The OpenCode release update, then `npm install --package-lock-only --save-exact` for OpenCode's closure.
2. `npm update --package-lock-only` for BrowserMCP.
3. The GitHub release binary updater (`leaf`, `wstunnel-relay`, `findersearch`).
4. The Gentle AI and Engram pinning (`gentle-ai-src` and `engram-src` in `flake.nix`, plus the coupled version literals).
5. `nix flake update --flake <selected-worktree>` for every input.
6. `nix-update --flake` from the repository root for `archify-skill` and `herdr`, plus `openfang` and `mcp-supermercados-cl` on Linux, and `--version=skip` (vendor hash only) for `gentle-ai` and `engram`.

It never builds derivations (beyond the fixed-output fetches `nix-update` needs to compute hashes), activates configurations, or pushes the Darwin system cache. A failed step reports its error and stops the following steps. The steps are not a transaction: after a failure, inspect `git diff` for already-updated files before retrying.

## What updates automatically

OpenCode's executable and its coupled npm closure advance together to the registry `latest` release of `@opencode/plugin`. The updater reads the registry (`NPM_CONFIG_REGISTRY` overrides it) and rewrites:

- `pkgs/opencode/default.nix`: `version` and each platform tarball `hash`, taken from the registry's integrity for that exact tarball.
- `pkgs/opencode-npm-packages-v2/package.json`: every `@opencode/*` pin to the release, `effect` and `@ai-sdk/provider` to the versions that release declares, and `@standard-schema/spec` to the version `@opencode/schema` declares. Other pins, such as `zod`, are independent and unchanged.

GitHub release binaries use the latest stable (non-prerelease) release from the GitHub API (`GITHUB_API_URL` overrides the base). Unauthenticated calls are limited to 60 per hour, so set `GITHUB_TOKEN` or `GH_TOKEN` (for example `GITHUB_TOKEN=$(gh auth token) nix-upgrade`); the token is sent only to the API host. Nix's own input fetching has the same limit and falls back to cached revisions for inputs it cannot refresh; configure `access-tokens` in `nix.conf` to avoid stale inputs. Every platform hash is recomputed from the downloaded asset, in the representation the file already uses.

Gentle AI and Engram inputs are pinned to the immutable commit of their latest stable release with a version tag (other tags such as Engram's `pi-v*` are skipped), never to a moving branch. The version literals that ship with Gentle AI are rewritten together. Their vendor hashes are recomputed afterwards. A newer release can require a newer Go toolchain or renderer changes than the pinned nixpkgs provides; the build then fails at validation, not at update time.

BrowserMCP's exact direct pins are preserved; eligible transitive dependencies update within their declared ranges. Its compatibility and port-ownership patches remain mandatory build checks. Floating flake inputs move to their latest revision.

Not updated by `nix-upgrade`: the patched quota plugin (it declares an exact peer on `@opencode/plugin` 2.0.16; it is vendored with the host's plugin runtime and its patches must be rebased by hand), `tinkertool` (its upstream is not a GitHub release), `rog-efi-poweroff`, and the deliberate nixpkgs overrides in `overlays/` (`teams-for-linux`, `symbola`, `afdko`, and the Darwin patches). A refreshed `nixpkgs` can retire pinned choices (for example a kernel marked end of life), so run `nixos-build check` and a build before activating; Gentle AI is certified against a specific OpenCode release in `docs/gentle-ai-update.md`.

## Packaging and validation

Both packages use `package.json` and `package-lock.json` with `buildNpmPackage` and `importNpmLock`. Each tarball's integrity comes from the standard lock: no separate hash manifest or `npmDepsHash` update is necessary. The pinned Nix hook installs offline, then runs `npm rebuild` for lifecycle scripts; it temporarily defers scripts during installation rather than disabling them globally.

The migration preserves all 22 original package versions and tarball integrities. Standard dependency resolution expands OpenCode's lock from 10 curated entries to 273 entries and BrowserMCP's from 12 to 93. These counts include nested and optional/platform entries, not just modules installed on one machine. This expansion was explicitly approved; future lock diffs still require inspection.

The installed `lib/node_modules` tree remains compatible with the existing Home Manager copy operation. OpenCode retains its dependency-map `package.json` output. BrowserMCP retains its executable wrapper, resource capability adjustments, and protection against killing an unrelated port owner.

```console
go -C pkgs/nixos-scripts test ./...
nix build 'path:.#opencode-npm-packages-v2' 'path:.#browsermcp-v2' --no-link
nix flake check path:. --no-build
```

Package builds run `check.mjs` against installed outputs, checking direct pins, integrity presence, layout, representative imports, and BrowserMCP patches/CLI behavior. These checks do not replace a live browser-extension session. `path:.` includes new files without staging; ordinary Git-flake commands omit untracked files. Before normal deployment, ensure the package manifests, locks, and tests are included in the repository through the separately authorized Git workflow.

Shared changes also require explicit evaluation of Darwin and standalone Home Manager targets; `flake check` alone does not cover them. No activation is part of validation. The four unpinned Darwin `npx` servers are follow-up work, not migrated here.

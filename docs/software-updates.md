# Update, validate, then activate

`nix-upgrade` changes source locks only. `nix-switch` builds and activates the selected configuration without updating its sources. Both aliases still delegate to `nixos-build`; no per-language commands are required.

## Workflow

From the selected repository worktree:

```console
nix-upgrade
git diff -- flake.lock pkgs/browsermcp-v2/package-lock.json
nixos-build check
nix-switch
```

Run the last command only when ready to activate. `nixos-build build` builds without activation. Existing `boot`, `test`, `dry`, and `safe` retain their behavior; `safe` includes activation.

Upgrade runs native `npm update --package-lock-only` for BrowserMCP, then `nix flake update --flake <selected-worktree>`. It does not build derivations, activate configurations, or push the Darwin system cache. A failed command reports its error and stops subsequent steps. These two updates are not a transaction: if the flake update fails, inspect the already-updated npm lock before retrying.

## What updates automatically

BrowserMCP's exact direct pins are preserved; eligible transitive dependencies update within their declared ranges. Its compatibility and port-ownership patches remain mandatory build checks. OpenCode's entire coupled npm lock remains frozen during ordinary upgrade. Flake updates change inputs, not literal versions in Nix files or npm manifests; inputs may still select newer software for a later build.

For an intentional, separately approved direct-version change, use npm rather than editing versions or hashes manually:

```console
npm install --prefix pkgs/browsermcp-v2 --package-lock-only --save-exact @browsermcp/mcp@<approved-version>
```

For OpenCode, use the same native command with `--prefix pkgs/opencode-npm-packages-v2` and the explicitly approved, compatible package versions together. Do not independently advance its coupled packages, OpenCode itself, or Gentle AI. No `latest`, peer-dependency bypass, or disabled lifecycle scripts is needed for the initial migration.

## Packaging and validation

Both packages use `package.json` and `package-lock.json` with `buildNpmPackage` and `importNpmLock`. Each tarball's integrity comes from the standard lock: no separate hash manifest or `npmDepsHash` update is necessary. The pinned Nix hook installs offline, then runs `npm rebuild` for lifecycle scripts; it temporarily defers scripts during installation rather than disabling them globally.

The migration preserves all 22 original package versions and tarball integrities. Standard dependency resolution expands OpenCode's lock from 10 curated entries to 285 entries and BrowserMCP's from 12 to 93. These counts include nested and optional/platform entries, not just modules installed on one machine. This expansion was explicitly approved; future lock diffs still require inspection.

The installed `lib/node_modules` tree remains compatible with the existing Home Manager copy operation. OpenCode retains its dependency-map `package.json` output. BrowserMCP retains its executable wrapper, resource capability adjustments, and protection against killing an unrelated port owner.

```console
go -C pkgs/nixos-scripts test ./...
nix build 'path:.#opencode-npm-packages-v2' 'path:.#browsermcp-v2' --no-link
nix flake check path:. --no-build
```

Package builds run `check.mjs` against installed outputs, checking direct pins, integrity presence, layout, representative imports, and BrowserMCP patches/CLI behavior. These checks do not replace a live browser-extension session. `path:.` includes new files without staging; ordinary Git-flake commands omit untracked files. Before normal deployment, ensure the package manifests, locks, and tests are included in the repository through the separately authorized Git workflow.

Shared changes also require explicit evaluation of Darwin and standalone Home Manager targets; `flake check` alone does not cover them. No activation is part of validation. The four unpinned Darwin `npx` servers are follow-up work, not migrated here.

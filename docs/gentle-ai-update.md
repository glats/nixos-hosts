# Gentle AI Update Workflow

This document describes how to update Gentle AI in this NixOS configuration.
Gentle AI is pinned to a **release tag** — never track `main` and never rely on
sync markers. Home Manager remains the sole deployment authority on all hosts.

## Overview

Gentle AI provides two independent derivations, both fed by the same pinned
input:

| Derivation | Source | Output path |
|------------|--------|-------------|
| `gentle-ai` | `gentle-ai-src` (Go binary, `cmd/gentle-ai`) | `bin/gentle-ai` |
| `gentle-ai-assets` | `gentle-ai-src` (skills, commands, plugins, overlays) | `$out/share/gentle-ai/` |

Tool-specific activation scripts (OpenCode, Claude Code) merge skills, commands,
and AGENTS.md fragments from all configured sources at activation time. The
four managed OpenCode plugins (`model-variants`, `opencode-review-transport`,
`sdd-task-result-artifacts`, `skill-registry`) are wired in
`shared/opencode/runtime-config.nix` and controlled by
`home.opencode.plugins.*.enable`.

## Update Steps (v2.x, in order)

### Step 1: Check the Latest v2.x Release

```bash
gh release list --repo Gentleman-Programming/gentle-ai
```

Note the latest release tag (for example `v2.5.0`).

### Step 2: Bump the Input Tag

In `flake.nix`, update the pinned tag:

```nix
gentle-ai-src = {
  url = "github:Gentleman-Programming/gentle-ai/v2.5.0";
  flake = false;
};
```

### Step 3: Re-lock the Input

```bash
nix flake lock --update-input gentle-ai-src
```

Confirm the lock resolves the tag (the `original.ref` must be the tag, not a
branch):

```bash
jq '.nodes["gentle-ai-src"]' flake.lock
```

### Step 4: Recompute the Go vendorHash

In `pkgs/gentle-ai/default.nix`, temporarily set:

```nix
vendorHash = lib.fakeHash;
```

Then build and copy the expected hash from the failure:

```bash
nix build .#gentle-ai 2>&1 | grep 'got:'
```

Put the printed `got: sha256-…` value into `vendorHash` and rebuild until
`nix build .#gentle-ai` succeeds.

### Step 5: Build Assets and Verify Plugins

```bash
nix build .#gentle-ai-assets
```

Assert the managed plugin set matches upstream:

```bash
ls "$(nix build .#gentle-ai-assets --no-link --print-out-paths)/share/gentle-ai/opencode/plugins/"
```

Every plugin file present upstream must have a matching
`shared/opencode/runtime-config.nix` entry; files removed upstream (such as
`background-agents.ts` in v2.5.0) must keep their activation-time cleanup.

### Step 6: Format and Evaluate

```bash
format-nix && nix flake check --no-build
```

`flake.nix` exposes checks containing all three NixOS hosts' toplevels, so
`--no-build` is mandatory while iterating.

### Step 7: Canary t14

```bash
nixos-build   # run on t14
```

Before switching, verify the generated agent graph preserves permissions and
emits no deprecated `tools` field:

```bash
out=$(nix build .#homeConfigurations.t14.activationPackage --no-link --print-out-paths)
jq -e '([.agent[]|has("permission")]|all) and ([.agent[]|has("tools")]|any|not) and
  (.agent["sdd-apply"].permission.edit=="allow") and
  (.agent["explore"].permission.write=="deny") and
  (.agent["gentle-orchestrator"].permission.task=={"*":"deny","sdd-*":"allow"})' \
  "$out/home-files/.config/opencode/opencode.json"
```

Also confirm on t14 that enabled plugins are deployed and retired plugin files
are gone after activation.

### Step 8: Roll Out Other Hosts

After the t14 canary passes, deploy rog, thinkcentre, and mact2 with
`nixos-build` on each host.

## Verification Checklist

- [ ] `nix build .#gentle-ai` succeeds (vendorHash accepted)
- [ ] `nix build .#gentle-ai-assets` succeeds and exposes the upstream plugin set
- [ ] Lock entry resolves the release tag
- [ ] `format-nix && nix flake check --no-build` passes
- [ ] t14 permission gate (jq above) returns `true`
- [ ] Enabled plugins deployed; disabled and legacy plugins removed on activation
- [ ] `caveman-assets` / `ponytail-assets` unaffected (independent inputs)

## Rollback

If something goes wrong:

1. Revert the tag and hash changes:

   ```bash
   git checkout HEAD~1 -- flake.nix flake.lock pkgs/gentle-ai/default.nix
   ```

   (or restore the previous tag/vendorHash values by hand if the commit is
   already merged)

2. Re-lock and rebuild:

   ```bash
   nix flake lock --update-input gentle-ai-src
   nix build .#gentle-ai-assets && nix flake check --no-build
   ```

3. If a retired plugin file must be removed after rollback, the activation
   script's unconditional cleanup (and `disabledManagedPluginNames` removals)
   handles it on the next rebuild — no imperative recovery is needed.

## Principles

1. **Always pin release tags** — never track a moving branch
2. **No sync markers** — `flake.lock` is the single source of truth
3. **Always use upstream plugins** — if there's a bug, PR to upstream
4. **Per-source derivations are independent** — no monolithic chain
5. **Local skills live in `local-ai-assets`** — never modify upstream source pins directly
6. **Permissions, not tools** — agent grants are `permission`-shaped (v2.5.0+)

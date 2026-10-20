---
name: nix-verify
description: >
  Use the nixos MCP to verify packages, options, and Nix functions before writing
  any NixOS or Home Manager configuration. Never hallucinate package names or option paths.
  Trigger: When editing `.nix` files only — adding packages to .nix, configuring services
  in .nix, searching for NixOS/Home Manager options to use in .nix, or looking up Nix library
  functions for .nix expressions. Do NOT trigger for JSON, YAML, TOML, or other non-Nix files.
license: Apache-2.0
metadata:
  version: "1.1"
---

## When to Use

This skill applies **only when editing `.nix` files**. Do NOT load for JSON, YAML, TOML, or
any non-Nix file, even if it lives inside a NixOS configuration repository.

- Adding a package to `environment.systemPackages` or `home.packages` **in a .nix file**
- Looking up a NixOS option path (e.g. `services.*.enable`) **to use in a .nix file**
- Looking up a Home Manager option path (e.g. `programs.*.enable`) **to use in a .nix file**
- Checking if a program is available via `programs.` in nixos/home-manager
- Looking up Nix library functions (`lib.attrsets.*`, `lib.strings.*`, etc.) **for .nix expressions**
- Checking historical package versions for reproducible builds
- Exploring flake inputs already pinned in `flake.lock`

## Critical Patterns

**NEVER guess package names or option paths.** Research first via MCP, then
verify against the repository's pinned inputs before treating a result as
compatible. A catalog hit alone is not proof for the target configuration.

Discover the live tool schema and available channels before querying. Record
the resolved channel/version; do not assume `stable` matches the repository
pin or let the default `unstable` silently stand in for it. Use an explicit
matching channel when supported. If unavailable, disclose the mismatch and
use the pinned source and target evaluation as compatibility evidence.
Do not update a pin to make it match the catalog.

The MCP exposes two tools:
- `nix(action, query, source, type, channel, limit)` — unified search/info
- `nix_versions(package, version, limit)` — historical versions with commit hashes

## Decision Table

| What you need | Tool call |
|---|---|
| Does package `foo` exist? | `nix(action="search", query="foo", source="nixos", type="packages")` |
| Exact package attribute path | `nix(action="info", query="foo", source="nixos", type="package")` |
| NixOS service/option | `nix(action="search", query="foo", source="nixos", type="options")` |
| Home Manager option | `nix(action="search", query="foo", source="home-manager")` |
| Is `foo` a `programs.*` entry? | `nix(action="search", query="foo", source="nixos", type="programs")` |
| nix-darwin option | `nix(action="search", query="foo", source="darwin")` |
| Nixvim option | `nix(action="search", query="foo", source="nixvim")` |
| Nix lib function | `nix(action="search", query="mapAttrs", source="noogle")` |
| Nix lib function details | `nix(action="info", query="lib.attrsets.mapAttrs", source="noogle")` |
| Pinned flake inputs | `nix(action="flake-inputs", type="list")` |
| Read file from flake input | `nix(action="flake-inputs", type="read", query="nixpkgs:flake.nix")` |
| Historical package version | `nix_versions(package="nodejs", version="20.0.0")` |
| Is package cached? | `nix(action="cache", query="foo", system="x86_64-linux")` |
| NixOS Wiki article | `nix(action="search", query="nvidia", source="wiki")` |

## Workflow

1. **Identify the target** — read the host/platform and relevant pinned inputs;
   query `nix(action="channels")` and inspect the live schema.
2. **Search first** — use the appropriate search/info calls with a matching
   explicit channel where supported. Examples below omit channel selection
   for brevity; they do not authorize using a mismatched default.
3. **Confirm compatibility** — inspect the pinned package or module source
   when the catalog cannot represent that version. For Home Manager and
   nix-darwin, verify their own pins rather than assuming the NixOS channel.
4. **Write authorized config** — format only touched Nix files, then run the
   repository's target-scoped evaluations and applicable shared checks.
   Report unavailable evidence as pending; never claim compatibility from
   an unrelated catalog, and never activate as part of verification.

## Common Patterns

### Adding a package

```bash
# Step 1: verify it exists and get attribute path
nix(action="info", query="ripgrep", source="nixos", type="package")

# Step 2: use the confirmed attribute path in config
# e.g. pkgs.ripgrep (not pkgs.rg or pkgs.ripgrepSearch)
```

### Configuring a service

```bash
# Step 1: find option prefix
nix(action="search", query="nginx", source="nixos", type="options")

# Step 2: get all sub-options
nix(action="options", source="nixos", query="services.nginx")
```

### Home Manager program

```bash
# Step 1: check if it's a programs.* entry
nix(action="search", query="git", source="home-manager")

# Step 2: browse available options
nix(action="options", source="home-manager", query="programs.git")
```

### Reproducible pin (specific version)

```bash
# Get nixpkgs commit hash for a specific version
nix_versions(package="nodejs", version="20.11.0")
# Use the returned commit hash to pin in flake inputs
```

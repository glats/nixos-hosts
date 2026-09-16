# Exploration: nix-verification-harness

## Current State

### The verification surface today

The repo has three independent verification mechanisms that are not yet aligned:

1. **flake.nix `formatter`** (flake.nix:398-403) — `nixpkgs-fmt` on three systems (x86_64-linux, x86_64-darwin, aarch64-darwin). `nixpkgs-fmt` is **archived upstream** ("Replaced by nixfmt"). Bare `nix fmt` (no args) passes the flake root to `nixpkgs-fmt`, which is not designed to recurse over a directory — it is meant for one file. `nix fmt -- <single.nix>` works; bare `nix fmt` is a footgun.
2. **`format-nix` Go binary** (pkgs/nixos-scripts/cmd/format-nix/main.go) — walks `/etc/nixos`, skips `.git` and `.worktrees`, and shells out to `nix fmt -- <file>` once per `.nix` file (212 files → 212 `nix` process spawns). Has a `--check` mode (formats a temp copy, diffs). This is the canonical full-repo driver, referenced in AGENTS.md and openspec/config.yaml (`testing.formatter: "format-nix"`).
3. **`checks.x86_64-linux`** (flake.nix:273-278) — exposes `rog`, `thinkcentre`, `t14` as `config.system.build.toplevel` derivations.

The tiered agent policy (committed in `df4bc05 docs(agents): tier nix verification gates`) maps onto these: tier 1 = `nix fmt -- <touched-file>`, tier 2 = targeted single-host eval, tier 3 = `format-nix && nix flake check --no-build`.

`.gitignore` already excludes `.worktrees/` (the full-repo copies format-nix skips manually).

## Affected Areas

- `flake.nix` — `formatter.*` (398-403), `checks.x86_64-linux` (273-278). The core of the change.
- `AGENTS.md` — "Formatting" table (`nixpkgs-fmt` → `nixfmt`), the warning that "`checks.x86_64-linux` contains all three NixOS hosts' toplevels", the tier policy wording.
- `pkgs/nixos-scripts/cmd/format-nix/main.go` — help text (anti-pattern note names `nixpkgs-fmt`), possibly the per-file loop.
- `openspec/config.yaml` — `testing.formatter: "format-nix"`, `testing.flake_check`.
- New file if adopted: `.git-blame-ignore-revs` (one treewide reformat commit), plus a `.gitattributes`/treefmt config only if treefmt-nix is adopted (not recommended).

## Research Findings (MCP-verified)

### 1. The formatter war is over: nixfmt (RFC-style) won, nixpkgs-fmt is dead

- `nix-community/nixpkgs-fmt` is **archived**, README reads "Replaced by [nixfmt](https://github.com/NixOS/nixfmt)". https://github.com/nix-community/nixpkgs-fmt
- RFC 166 established the standard Nix format and the official formatter, maintained by the Nix formatting team. https://github.com/NixOS/rfcs/blob/master/rfcs/0166-nix-formatting.md
- The `nixfmt-rfc-style` → `nixfmt` rename already landed in nixpkgs (commit `d1a4769`, July 2025): on nixos-26.05, `pkgs.nixfmt` **is** the RFC-style formatter; `pkgs.nixfmt-classic` is on the way out (https://github.com/NixOS/nixfmt/issues/340). Using `nixfmt-rfc-style` now emits a deprecation warning. https://github.com/NixOS/nixpkgs/commit/d1a4769b38bad1538d8b7aab3d337809f5bb5bd3 ; https://github.com/nixos/nixpkgs/issues/425583

**Implication:** staying on `nixpkgs-fmt` is a dead end; migration is a when-not-if. The correct target attribute on 26.05 is `pkgs.nixfmt`.

### 2. How `nix fmt` should walk a tree: `nixfmt-tree`, not treefmt-nix

The Nix formatting team's own guidance (nixfmt README + nix manual) is:

```nix
formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
```

`pkgs.nixfmt-tree` is a `treefmt` instance pre-configured with nixfmt. It makes bare `nix fmt` discover the flake root and format `*.nix` across the whole tree (parallel, change-cached), while `nix fmt -- ./file.nix` still formats one file. https://github.com/NixOS/nixfmt ; https://releases.nixos.org/nix/nix-2.34.8/manual/command-ref/new-cli/nix3-fmt.html

Crucially, the nixfmt maintainers themselves describe `treefmt-nix` as "quite overkilled if you simply want to format a small nix-only code base" and note that passing directories to bare `nixfmt` "is deprecated and will be unsupported soon". https://github.com/NixOS/nixfmt/issues/273

**Implication:** for a Nix-only repo, the sanctioned one-line answer is `nixfmt-tree` as the `formatter` attr. `treefmt-nix` (the flake-parts module) is overkill unless we want multiple languages or deadnix/statix wired in as treefmt "formatters" — neither applies here.

### 3. `nix flake check` semantics make the current `checks` block redundant

The Nix source `src/nix/flake-check.md` lists the outputs that "must be derivations" and are therefore always evaluated:

- `checks.<system>.<name>`
- `devShells.<system>.default` / `.name`
- **`nixosConfigurations.<name>.config.system.build.toplevel`**
- `packages.<system>.default` / `.name`

https://github.com/NixOS/nix/blob/master/src/nix/flake-check.md

`homeConfigurations` and `darwinConfigurations` are **not** on that list. So `nix flake check --no-build` evaluates the three NixOS hosts' toplevels **twice** today: once mandatorily as `nixosConfigurations.<h>` and again as `checks.x86_64-linux.<h>`. `nix flake check` is also known to be uncached and memory-hungry: https://github.com/NixOS/nix/issues/4279 , https://github.com/NixOS/nix/issues/13483

**Implication:** removing the toplevels from `checks` does not remove host evaluation (it's mandatory), but it halves the host-eval portion of tier 3 and, more importantly, restores the semantic meaning of `checks` = "cheap gates", not "build every host". The slow part of tier 3 is inherent to having `nixosConfigurations` as outputs — which is why tier 2 (targeted single-host eval) is the correct fast path and already exists.

### 4. deadnix: real but noisy and its auto-fix is unsafe

deadnix scans for unused `let` bindings, lambda args, and lambda attrset-pattern names. Two problems for this repo:

- The `--edit` mode is documented-unsafe: it removes lambda args without respecting the call site, changing a module's interface (https://github.com/astro/deadnix/issues/113).
- NixOS module files use the fixed signature `{ config, lib, pkgs, ... }: { ... }`. Any module that doesn't use one of those is flagged, so deadnix needs `-L/--no-lambda-pattern-names` (and usually `-_/--no-underscore`) to be usable — which disables the highest-value class of findings.

https://github.com/astro/deadnix

### 5. statix: cosmetic antipatterns, a second parser, known false positives

statix lints `bool_comparison`, `useless_parens`, `manual_inherit`, `eta_reduction`, `unquoted_uri`, etc. Two costs: it parses with `rnix-parser` (a second, slower-moving parser alongside nixfmt's), and it has documented false positives — `redundant_pattern_bind` breaks the type-asserting idiom `x @ { ... }:` (https://github.com/nerdypepper/statix/issues/64). The value over `nixfmt`'s normalization is marginal for a config repo. https://github.com/nerdypepper/statix

### 6. git-hooks.nix fits `nix develop`, not this repo's agent flow

git-hooks.nix wires pre-commit hooks two ways: as a `checks` derivation (read-only sandbox — "cannot modify files", so formatting hooks that auto-fix don't work there) or via a devShell `shellHook` that installs `.pre-commit-config.yaml` (only fires when you commit **inside** `nix develop`, and "nix-shell … does bring some latency when committing"). https://github.com/cachix/git-hooks.nix

Agents in this repo commit via OpenCode/Claude Code, not necessarily from inside a `nix develop` shell, and the AGENTS.md tier policy already encodes "format before commit" as an explicit step (not an implicit hook). A hook that silently rewrites staged files would also fight the repo's work-unit-commits discipline.

### 7. flake-checker fights the repo's deliberate pin

Determinate Systems' flake-checker verifies nixpkgs input freshness/supportedness; its default policy is `< 30 days old` + `owner == 'NixOS'`. The repo's whole `nixos-26.05` pin exists *because* 26.11 dropped x86_64-darwin for mact2 — a checker that nags "you're outdated" would produce a permanent false positive, or require a bespoke CEL condition the maintainer has to babysit. https://github.com/DeterminateSystems/flake-checker

### 8. Prior art: where multi-host flakes put their builds

- **Misterio77/nix-config (Foundry)** — does **not** put host toplevels in `checks`; exposes a `hydraJobs` output and builds every host with self-hosted **Hydra** + a binary cache. Still on `formatter = pkgs.alejandra`. https://github.com/Misterio77/nix-config
- **NotAShelf/nyx** — flake-parts + `treefmt-nix` (formatter) + `git-hooks.nix` (pre-commit) + `nixfmt` as a flake input; `checks` holds *small additional checks*, not host toplevels. Explicitly the "overengineered monorepo" reference. https://github.com/NotAShelf/nyx

Both are far bigger than this 5-host personal flake, and both treat `checks` as small/fast gates while host builds live elsewhere (Hydra) or in targeted deploys.

## Approaches

### Question 1 — Formatter migration

1. **Migrate `formatter.*` to `pkgs.nixfmt` (bare)** — correct formatter, but bare `nix fmt` stays a directory footgun.
2. **Migrate to `pkgs.nixfmt-tree`** (recommended) — one-line change; bare `nix fmt` walks the tree safely, `nix fmt -- <file>` still works, and treefmt's change-cache/parallelism makes full-repo formatting fast. Effort: Low.
3. **Adopt treefmt-nix** — flake-parts module; overkill for a Nix-only repo (maintainers' own words). Effort: Medium (new input + config module). Defer.

### Question 2 — Linters

- **deadnix** — defer; adopt later as an *opt-in* cleanup (`nix run` with `-L -_`, never `--edit`), not a gate.
- **statix** — reject as a gate; cosmetic + false positives + second parser.

### Question 3 — Checks structure

1. **Keep 3 toplevels in `checks`** (status quo) — redundant double evaluation.
2. **Remove toplevels; `checks` = cheap gates only** (recommended) — e.g. a single formatting check. Effort: Low. Hosts are still evaluated via `nixosConfigurations` (mandatory), so no coverage loss.
3. **nix-eval-jobs / nix-fast-build** — only pays off with a CI build matrix (Hydra/Hercules), which this repo doesn't have. Defer.

### Question 4 — Commit gates

- **git-hooks.nix** — defer; conflicts with agent commit flow and the explicit tier policy. Revisit only if human contributors multiply.

### Question 5 — CI

- **GitHub Actions (nix-installer-action + magic-nix-cache/cachix)** — reject. Hosts build locally (`nixos-build`), there are no external PRs, and macOS systems (mact2 x86_64-darwin, macm5 aarch64-darwin) can't build on GH runners anyway.

## Recommendation — target harness

### Adopt / defer / reject

| Verdict | Tool | Effort | One-line justification |
|---|---|---|---|
| **Adopt** | `pkgs.nixfmt` (rfc-style) | Low-Med | nixpkgs-fmt is archived; 26.05 names it `nixfmt`; one treewide reformat + blame-ignore. |
| **Adopt** | `pkgs.nixfmt-tree` as `formatter` | Low | Makes bare `nix fmt` walk the tree safely; the sanctioned wrapper; replaces the per-file footgun. |
| **Adopt** | Drop toplevels from `checks`; add a cheap format check | Low | `nix flake check` already evaluates `nixosConfigurations`; current block double-evaluates. |
| **Defer** | treefmt-nix | — | Overkill for Nix-only repo; revisit only for multi-language or linters-as-formatters. |
| **Defer** | deadnix | Low | Opt-in cleanup only; `--edit` unsafe, noisy on module signatures without `-L -_`. |
| **Defer** | git-hooks.nix | Medium | Fits `nix develop`, not agent commits; sandbox can't auto-fix; fights work-unit discipline. |
| **Defer** | nix-eval-jobs / hydraJobs | Medium | Only with a self-hosted Hydra build matrix, which we're not adopting. |
| **Reject** | statix | — | Cosmetic + false positives + second (rnix) parser. |
| **Reject** | flake-checker | — | Default policy (30-day freshness) contradicts the deliberate 26.05 pin. |
| **Reject** | GitHub Actions CI | — | Local-only builds, no PRs, macOS unrunnable on GH runners. |

### Mapping onto the tier policy

- **Tier 1** (`nix fmt -- <touched-file>`) → backed by **nixfmt** (unchanged command, new formatter).
- **Tier 2** (targeted single-host eval) → unchanged; already the correct fast path (t14 ~2 min cold).
- **Tier 3** (`format-nix && nix flake check --no-build`) → `format-nix` stays the full-repo driver (or collapses to bare `nix fmt` once `nixfmt-tree` handles `.gitignore`/`.worktrees`); `nix flake check --no-build` keeps evaluating `nixosConfigurations` (mandatory) but drops the redundant `checks` toplevels and gains a cheap format check.

### Concrete deltas

- **flake.nix**: `formatter.*` → `nixpkgs.legacyPackages.<sys>.nixfmt-tree` (3 lines). Delete `checks.x86_64-linux = { rog; thinkcentre; t14; }`; add a single `checks.x86_64-linux.format` (nixfmt over the tree in `--fail-on-change` mode, via a `runCommand`/`writeShellApplication` — exact treefmt flag to confirm in design).
- **AGENTS.md**: formatter table `nixpkgs-fmt` → `nixfmt`; drop the "checks.x86_64-linux contains all three NixOS hosts' toplevels" warning; tier text otherwise unchanged.
- **pkgs/nixos-scripts**: `format-nix` help text anti-pattern note `nixpkgs-fmt` → `nixfmt`. Optional shrink: retire the per-file loop if `nix fmt` (nixfmt-tree) fully subsumes it.
- **openspec/config.yaml**: `testing.formatter` stays `format-nix` (or becomes `nix fmt`).
- **New**: `.git-blame-ignore-revs` with the treewide reformat commit hash; one treewide reformat commit.

### What gets deleted (the harness shrinks, not grows)

- `checks.x86_64-linux = { rog; thinkcentre; t14; }` (3 lines, redundant).
- All `nixpkgs-fmt` references (flake + AGENTS.md + format-nix help).
- Optionally: `format-nix`'s per-file loop (212 process spawns → one `nix fmt`).

## Constraints & Risks

- **nixos-26.05 pin**: `nixfmt-tree`/`nixfmt` must be confirmed present in 26.05 (they landed in the 24.11 cycle, so they are; verify during design).
- **Treewide reformat churn**: ~212 files will diff once. Mitigate with `.git-blame-ignore-revs`; this is the same pattern nixpkgs used (https://github.com/NixOS/nixpkgs/pull/380990).
- **Blind spot (surprise)**: `nix flake check` does **not** evaluate `darwinConfigurations` or standalone `homeConfigurations`, so mact2/macm5 and the standalone HM builds are *not* covered by tier 3 — only by tier-2 targeted eval or an on-device `nixos-build`. This is true today and stays true after the change; worth documenting in AGENTS.md.
- **`--check` parity**: `format-nix --check` semantics must survive either by keeping the binary or by mapping to treefmt's `--fail-on-change`.

## Ready for Proposal

Yes — with one clarification the orchestrator should surface to the user: whether `format-nix` should be **retired** (bare `nix fmt` via `nixfmt-tree` subsumes it, and `.worktrees/` is already gitignored) or **kept** as the canonical `/etc/nixos`-scoped driver. Everything else is a clear adopt/defer/reject with low-effort deltas.

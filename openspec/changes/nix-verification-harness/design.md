# Design: Nix Verification Harness

## Technical Approach

Adopt the pinned nixos-26.05 `nixfmt-tree` wrapper on every supported formatter system, isolate its RFC-166 rewrite, then make flake checks cheap and explicit. Local evaluation resolved `nixfmt-tree-2.5.0` on `x86_64-linux`, `x86_64-darwin`, and `aarch64-darwin`, and `nixfmt-1.4.0`; the nixpkgs package declares all platforms and configures treefmt with `includes = [ "*.nix" ]`. Official nixfmt/treefmt documentation confirms bare-tree and targeted-path operation.

## Architecture Decisions

| Decision | Choice | Evidence and rationale |
|---|---|---|
| Formatter outputs | Set all three `formatter.<system>` values to `nixpkgs.legacyPackages.<system>.nixfmt-tree`. | Uses RFC-166 `pkgs.nixfmt` internally; `nixfmt-rfc-style` is unnecessary and warning-prone. Non-`.nix` files are traversed but unmatched. |
| Format check | Admit `checks.x86_64-linux.format`. | Pinned treefmt 2.5.0 was tested: `--ci --walk filesystem --tree-root DIR` exits zero for formatted input and non-zero after drift. It needs no network or IFD in the derivation. Copy `${self}` to writable storage because `--ci` formats before failing. |
| `format-nix` parity | Keep per-file traversal; create check copies inside the repository with pattern `.format-nix-*.nix`. | The current extensionless `/tmp` copy emits zero files under `includes = [ "*.nix" ]`; an outside-root path is also unsafe for treefmt root selection. Keeping the loop preserves ignored-file coverage and messages. |
| Check coverage | Replace the three custom host checks with only `format`. | Native `nix flake check` already evaluates every `nixosConfiguration`; Darwin and standalone Home Manager remain explicit targeted evaluations. |

The final flake shape is:

```nix
checks.x86_64-linux.format =
  let pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in pkgs.runCommand "nix-format-check" { nativeBuildInputs = [ pkgs.nixfmt-tree ]; } ''
    cp -r ${self} source
    chmod -R u+w source
    cd source
    treefmt --ci --walk filesystem --tree-root .
    touch $out
  '';
```

## Data Flow

`nix fmt [-- path]` → flake `nixfmt-tree` → treefmt selects `*.nix` → `nixfmt`. The flake check performs the same flow on a writable source snapshot. `format-nix --check` instead formats repository-local `.nix` temporary copies and byte-compares them, never mutating tracked files.

## File Changes

| File | Action | Description |
|---|---|---|
| `flake.nix` | Modify | Switch three formatters; replace host checks with format check. |
| `**/*.nix` | Reformat | One RFC-166-only commit. |
| `pkgs/nixos-scripts/cmd/format-nix/main.go` | Modify | Rename anti-pattern text and use repository-local `.nix` check copies. |
| `pkgs/nixos-scripts/cmd/format-nix/main_test.go` | Modify | Prove temp-copy suffix/location and retained traversal exclusions. |
| `AGENTS.md` | Modify | Tier 1 remains targeted; tier 3 is `format-nix --check` in the main checkout or `nix fmt -- --ci` in a worktree, followed by `nix flake check --no-build`. State the Darwin/HM blind spot and list targeted output forms. |
| `openspec/config.yaml` | Modify | Keep `testing.formatter: format-nix` and both flake-check commands; make apply guidance worktree-safe. |
| `.git-blame-ignore-revs` | Create | Record the exact later format-commit hash. |

No Nix module option interface changes.

## Testing Strategy

Tier 1 runs `nix fmt -- <touched.nix>` and Go tests. Reformat proof requires the format commit to contain only `.nix` paths, `nix fmt -- --ci` to pass afterward, and tier-3 evaluation to stay green; diff statistics alone are not proof. Tier 2 evaluates all three NixOS toplevel drvPaths, both Darwin toplevel drvPaths, and all five standalone Home Manager activation drvPaths. Tier 3, from the worktree, runs `nix fmt -- --ci`, `go -C pkgs/nixos-scripts test ./...`, `nix build .#nixos-scripts`, and `nix flake check --no-build`.

## Threat Matrix

| Boundary | Applicability | Safe/failure behavior and RED test |
|---|---|---|
| Documentation-like paths | N/A | No executable classification changes; treefmt deliberately ignores non-`.nix` paths. |
| Git repository selection | Applicable | Cwd selects the worktree; `format-nix` selects `/etc/nixos`. RED-test repository-local `.nix` temp creation and absence of outside-root paths. |
| Commit state | N/A | No index or commit automation. |
| Push state | N/A | No push behavior. |
| PR commands | N/A | No PR behavior. |

## Migration / Rollout

Commit 1 changes formatter wiring and `format-nix` compatibility/tests. Commit 2 runs bare `nix fmt` once from the worktree root and contains only formatting. Commit 3 creates `.git-blame-ignore-revs` with commit 2's hash. Commit 4 removes redundant checks, adds the admitted format check, and updates guidance/config. Roll back in reverse order.

## Open Questions

None.

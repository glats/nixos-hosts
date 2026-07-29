# Proposal: darwin-audit-cleanup

## Intent

Strip dead weight from Darwin config. 5 trivial housekeeping fixes found during `mact2` audit. Each independently reverts. No new capabilities — pure deletion/simplification.

## Scope

### In Scope
1. `darwin/home/vscode.nix` — set `package = null` (homebrew cask only, ~500MB nix store saved)
2. `overlays/darwin.nix` — delete ghostty override (`package = null` on Darwin, dead code)
3. `flake.nix` — drop duplicate `activeProviderName` from mact2 standalone HM (already in `mact2/default.nix`)
4. `shared/packages.nix` — `gnupg1` → `gnupg` (modern, ~50MB, 1 less dep)
5. `shared/mise.nix` — strip dead brew branches (mise from nixpkgs now; 3/4 scripts never run)

### Out of Scope (Deferred)
- wireguard, colima, wsdd, mcps-extra, providers-extra (need more audit)

### Capabilities

**New**: None
**Modified**: None (pure cleanup — no spec-level behavior changes)

## Approach

5 independent edits, each revertable in isolation. Order doesn't matter. Run `format-nix && nix flake check --no-build` per edit.

## Affected Areas

| File | Impact | Edit |
|------|--------|------|
| `darwin/home/vscode.nix` | Modified | `package = null` |
| `overlays/darwin.nix` | Modified | Delete ghostty override |
| `flake.nix` | Modified | Drop dup `activeProviderName` |
| `shared/packages.nix` | Modified | s/gnupg1/gnupg |
| `shared/mise.nix` | Modified | Strip dead brew branches |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| gnupg1→gnupg breaks gpg key compat | Low | gnupg is modern GPG, backward compat |
| VSCode without nix pkg breaks cask dep | Low | Homebrew cask works standalone |

## Rollback Plan

Revert any file independently with `git checkout HEAD -- <file>`.

## Success Criteria

- [ ] `nix build .#darwinConfigurations.mact2.config.system.build.toplevel` succeeds
- [ ] `nix flake check --no-build` passes for any Linux host (regression guard)
- [ ] `du -sh /nix/store/*vscode*` shows no nix-packaged VSCode (only cask)

# Tasks: Engram Vanilla Integration

## Phase 1: Foundation — Vanilla Derivation + Flake Input

- [x] 1.1 Add `engram-src` input to `flake.nix` (pinned `v1.14.6`, `flake = false`), with comment explaining the tag must match `pkgs/engram/default.nix` version. Add `engram-src` to the `outputs` pattern destructure.
- [x] 1.2 Create `pkgs/engram-assets/vanilla.nix`: pure derivation copying `plugin/opencode/engram.ts` from `engram-src` to `$out/share/engram/opencode/plugins/engram.ts`. Fail with clear message if source file missing.
- [x] 1.3 Wire `engram-assets-vanilla` in flake.nix: `pkgs.callPackage ./pkgs/engram-assets/vanilla.nix { inherit engram-src; }`, add to `packages.${system}`.

## Phase 2: Core — Layered Derivation + Flake Wiring

- [x] 2.1 Create `pkgs/engram-assets/default.nix`: layered derivation importing `vanilla` param, using `substituteInPlace` to set ENGRAM_BIN default to `${engram}/bin/engram`. Use `dontUnpack = true` pattern (copy from vanilla into temp dir, patch, install to `$out/share/engram/`).
- [x] 2.2 Wire `engram-assets` in flake.nix: `pkgs.callPackage ./pkgs/engram-assets/default.nix { vanilla = engram-assets-vanilla; }`, add to `packages.${system}`.
- [x] 2.3 Add `engram-assets` and `engram-assets-vanilla` to overlay in `modules/base/overlays.nix` via the `inherit (self.packages.${prev.stdenv.hostPlatform.system})` line.

## Phase 3: Integration — Binary Bump, Module Update, File Deletion

- [x] 3.1 Bump `pkgs/engram/default.nix`: version `"1.12.0"` → `"1.14.6"`, update sha256 hash (fetch upstream tarball, compute new hash).
- [x] 3.2 Modify `modules/home/opencode.nix` line 109: replace `${./opencode/plugins/engram.ts}` with `${pkgs.engram-assets}/share/engram/opencode/plugins/engram.ts`. Preserve existing toggle gating.
- [x] 3.3 Delete `modules/home/opencode/plugins/engram.ts` (449-line local copy no longer needed).

## Phase 4: Verification

- [x] 4.1 Build vanilla: `nix build .#engram-assets-vanilla` — verify output contains `share/engram/opencode/plugins/engram.ts` and content matches upstream.
- [x] 4.2 Build layered: `nix build .#engram-assets` — verify ENGRAM_BIN references resolve to nix store path (not `/usr/local/bin/engram`).
- [x] 4.3 Build binary: `nix build .#engram` — verify engram binary compiles at v1.14.6 and is executable.
- [x] 4.4 Full check: run `nix flake check` and `nixos-build dry` — confirm zero errors.

(End of file - total 26 lines)

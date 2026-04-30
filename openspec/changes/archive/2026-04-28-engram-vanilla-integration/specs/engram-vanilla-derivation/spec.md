# Engram Vanilla Derivation Specification

## Purpose

Define a pure upstream derivation that extracts the `engram.ts` OpenCode plugin from the `engram-src` flake input without modification, establishing a reproducible baseline for the engram plugin.

## Requirements

### Requirement: Pure Upstream Plugin Copy

The vanilla derivation MUST copy `plugin/opencode/engram.ts` from `engram-src` to `$out/share/engram/opencode/plugins/engram.ts` without any modification. The output MUST be byte-identical to the upstream file.

#### Scenario: Vanilla produces byte-identical plugin

- GIVEN `engram-src` is pinned to `v1.14.6`
- WHEN `nix build .#engram-assets-vanilla` completes
- THEN `$out/share/engram/opencode/plugins/engram.ts` exists
- AND its content matches `plugin/opencode/engram.ts` from the upstream repo at `v1.14.6`

#### Scenario: Vanilla handles missing plugin path gracefully

- GIVEN `engram-src` does NOT contain `plugin/opencode/engram.ts`
- WHEN the derivation runs
- THEN the build fails with a clear error message about the missing file
- AND no partial output is produced

### Requirement: Standalone Derivation

The vanilla derivation MUST be a standalone Nix derivation, buildable independently via `nix build .#engram-assets-vanilla`.

#### Scenario: Vanilla derivation builds independently

- GIVEN the flake exposes `engram-assets-vanilla` as a package
- WHEN running `nix build .#engram-assets-vanilla`
- THEN the build succeeds and produces a valid output path

#### Scenario: Vanilla derivation accepts only engram-src

- WHEN inspecting the vanilla derivation inputs
- THEN it accepts only `engram-src` and standard Nixpkgs arguments
- AND it does NOT accept any local override parameters

### Requirement: Correct Output Path Structure

The output MUST follow the path convention `$out/share/engram/opencode/plugins/engram.ts`, matching the Gentle AI asset structure pattern (`$out/share/<project>/opencode/plugins/`).

#### Scenario: Output path matches convention

- GIVEN the derivation completes successfully
- WHEN inspecting the output directory tree
- THEN the file exists at `$out/share/engram/opencode/plugins/engram.ts`
- AND no other files exist outside this path

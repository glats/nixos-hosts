# Proposal: HM Suites Organization

## Why

MATE HM modules flat in `linux/home/`, imported via `shared-modules.nix`. t14 (Omarchy) pulls MATE config it never uses. Group under `suites/mate/`, import per-host.

## Scope

6 files moved, 0 behavior changes.

## Approach

`git mv` 4 MATE modules to `suites/mate/`, 1 rog-specific to `suites/mate-rog/`. Create `suites/mate/default.nix` aggregator. Remove MATE entries from `shared-modules.nix`. Add suite import to rog + thinkcentre.

## Rollback

`git revert` — pure moves + path changes.